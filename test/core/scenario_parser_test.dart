import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/qa_agent.dart';

void main() {
  group('ScenarioParser Core', () {
    final parser = ScenarioParser();

    test('parses valid yaml scenario string into TestScenario model', () {
      const source = '''
id: sample_scenario
name: Sample Test Scenario
tags: [smoke, test]
steps:
  - inspect_widget_tree: true
  - enter_text:
      key: login.id
      value: "1234567890"
  - tap:
      key: login.submit
''';
      final scenario = parser.parse(source);
      expect(scenario.id, equals('sample_scenario'));
      expect(scenario.name, equals('Sample Test Scenario'));
      expect(scenario.tags, containsAll(<String>['smoke', 'test']));
      expect(scenario.steps.length, equals(3));
      expect(scenario.steps[0].action, equals(StepAction.inspectWidgetTree));
      expect(scenario.steps[1].action, equals(StepAction.enterText));
      expect(scenario.steps[2].action, equals(StepAction.tap));
    });

    test('throws FormatException if name is missing', () {
      const source = '''
id: invalid_sample
steps:
  - tap:
      key: login.submit
''';
      expect(() => parser.parse(source), throwsFormatException);
    });

    test('throws FormatException if steps list is empty', () {
      const source = '''
id: empty_steps
name: Empty Steps Scenario
steps:
''';
      expect(() => parser.parse(source), throwsFormatException);
    });
  });
}
