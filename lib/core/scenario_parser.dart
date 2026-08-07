import 'dart:io';

import 'package:penguin_pos_qa_agent/core/models.dart';

enum _Section { none, steps, credentials, assertions }

/// Lightweight YAML subset parser for declarative POS test scenarios.
class ScenarioParser {
  Future<TestScenario> parseFile(String path) async =>
      parse(await File(path).readAsString());

  TestScenario parse(String source) {
    String? id;
    String? name;
    final tags = <String>[];
    final steps = <TestStep>[];
    _DraftStep? current;
    _Section section = _Section.none;

    for (final raw in source.split('\n')) {
      final line = raw.split('#').first;
      if (line.trim().isEmpty) continue;
      final indent = line.length - line.trimLeft().length;
      final text = line.trim();

      if (indent == 0) {
        if (current != null) {
          steps.add(current.build());
          current = null;
        }
        if (text.startsWith('id:')) {
          id = _value(text);
          section = _Section.none;
          continue;
        }
        if (text.startsWith('name:')) {
          name = _value(text);
          section = _Section.none;
          continue;
        }
        if (text.startsWith('tags:')) {
          tags.addAll(
            _value(text)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty),
          );
          section = _Section.none;
          continue;
        }
        if (text.startsWith('steps:')) {
          section = _Section.steps;
          continue;
        }
        if (text.startsWith('credentials:')) {
          section = _Section.credentials;
          continue;
        }
        if (text.startsWith('assertions:')) {
          section = _Section.assertions;
          continue;
        }
      }

      if (section == _Section.steps) {
        if (text.startsWith('- ')) {
          if (current != null) steps.add(current.build());
          final pair = text.substring(2);
          final colon = pair.indexOf(':');
          if (colon < 1) throw FormatException('Invalid step: $text');
          final action = _parseAction(pair.substring(0, colon).trim());
          final rest = pair.substring(colon + 1).trim();
          current = _DraftStep(action);
          if (rest.isNotEmpty) current.payload['value'] = _scalar(rest);
          continue;
        }
        if (indent >= 2 && current != null && text.contains(':')) {
          final colon = text.indexOf(':');
          current.payload[text.substring(0, colon).trim()] = _scalar(
            text.substring(colon + 1).trim(),
          );
        }
      }
    }
    if (current != null) steps.add(current.build());
    if (name == null || name.isEmpty) {
      throw const FormatException('Scenario requires name');
    }
    if (steps.isEmpty) {
      throw const FormatException('Scenario must have at least one step');
    }
    return TestScenario(
      id: id ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      name: name,
      steps: steps,
      tags: tags,
    );
  }

  String _value(String text) => text
      .substring(text.indexOf(':') + 1)
      .trim()
      .replaceAll(RegExp("^['\\\"]|['\\\"]\$"), '');

  Object _scalar(String raw) {
    final quoted =
        raw.length >= 2 &&
        ((raw.startsWith("'") && raw.endsWith("'")) ||
            (raw.startsWith('"') && raw.endsWith('"')));
    final value = quoted ? raw.substring(1, raw.length - 1) : raw;
    if (quoted) return value;
    if (value == 'true') return true;
    if (value == 'false') return false;
    return num.tryParse(value) ?? value;
  }

  StepAction _parseAction(String value) => switch (value) {
    'login' => StepAction.login,
    'enter_text' => StepAction.enterText,
    'tap' => StepAction.tap,
    'wait_for' => StepAction.waitFor,
    'inspect_widget_tree' => StepAction.inspectWidgetTree,
    'scan' => StepAction.scan,
    'weight' => StepAction.weight,
    'loyalty' => StepAction.loyalty,
    'payment' => StepAction.payment,
    'verify_receipt' => StepAction.verifyReceipt,
    'offline' => StepAction.offline,
    'sync' => StepAction.sync,
    'verify' => StepAction.verify,
    _ => throw FormatException('Unsupported action: $value'),
  };
}

class _DraftStep {
  _DraftStep(this.action);
  final StepAction action;
  final Map<String, Object?> payload = <String, Object?>{};

  TestStep build() {
    if (action == StepAction.verifyReceipt && payload.containsKey('value')) {
      if (payload['value'] != true) {
        throw const FormatException('verify_receipt only supports true');
      }
      payload.remove('value');
    }
    if (action == StepAction.offline && payload.containsKey('value')) {
      payload['enabled'] = payload.remove('value');
    }
    return TestStep(action: action, payload: payload);
  }
}
