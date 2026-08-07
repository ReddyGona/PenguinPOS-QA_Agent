import 'dart:convert';
import 'dart:io';

import '../result.dart';

/// Reports scenario execution results as indented JSON files.
class JsonReporter {
  Future<File> write(
    ScenarioResult result, {
    String directory = 'reports',
  }) async {
    final folder = Directory(directory);
    await folder.create(recursive: true);
    final timestamp = result.startedAt.toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File('${folder.path}/${result.scenario.id}_$timestamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'scenario': <String, Object?>{
          'id': result.scenario.id,
          'name': result.scenario.name,
          'tags': result.scenario.tags,
        },
        'status': result.status.name,
        'startedAt': result.startedAt.toUtc().toIso8601String(),
        'finishedAt': result.finishedAt.toUtc().toIso8601String(),
        'steps': result.steps
            .map(
              (s) => <String, Object?>{
                'action': s.step.action.name,
                'status': s.status.name,
                'durationMs': s.duration.inMilliseconds,
                if (s.message != null) 'message': s.message,
              },
            )
            .toList(),
        if (result.failure != null)
          'failure': <String, Object?>{
            'category': result.failure!.category,
            'confidence': result.failure!.confidence,
            'recommendation': result.failure!.recommendation,
          },
      }),
    );
    return file;
  }
}
