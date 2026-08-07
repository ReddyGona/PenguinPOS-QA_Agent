import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/qa_agent.dart';

void main() {
  group('Login Scenario Parser', () {
    final parser = ScenarioParser();

    test('parses valid_login scenario file', () async {
      final scenario = await parser.parseFile(
        'scenarios/login/valid_login.yaml',
      );
      expect(scenario.id, equals('valid_login'));
      expect(scenario.tags, containsAll(<String>['smoke', 'login', 'qa']));
      expect(scenario.steps, isNotEmpty);
      expect(
        scenario.steps.first.action,
        equals(StepAction.inspectWidgetTree),
      );
    });

    test('parses invalid_credentials scenario file', () async {
      final scenario = await parser.parseFile(
        'scenarios/login/invalid_credentials.yaml',
      );
      expect(scenario.id, equals('invalid_credentials'));
      expect(
        scenario.tags,
        containsAll(<String>['regression', 'login', 'negative']),
      );
      expect(scenario.steps.length, equals(4));
    });

    test('parses empty_credentials scenario file', () async {
      final scenario = await parser.parseFile(
        'scenarios/login/empty_credentials.yaml',
      );
      expect(scenario.id, equals('empty_credentials'));
      expect(
        scenario.tags,
        containsAll(<String>['regression', 'login', 'validation']),
      );
      expect(scenario.steps.length, equals(2));
    });
  });
}
