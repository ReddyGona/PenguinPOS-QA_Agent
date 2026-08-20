import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_definition.dart';
import 'package:penguin_pos_qa_agent/domain/suites/qa_suite_registry.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';

class _MockSuiteDefinition extends QaSuiteDefinition {
  const _MockSuiteDefinition({
    required this.id,
    required this.title,
    required this.description,
    this.isImplemented = true,
  });

  @override
  final QaSuiteId id;
  @override
  final String title;
  @override
  final String description;
  @override
  final bool isImplemented;

  @override
  Future<ExecutionPlanResult> execute({
    required Driver driver,
    required Uri vmServiceUri,
    required PreparedExecution execution,
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) async {
    return ExecutionPlanResult(
      plan: execution.plan,
      profileId: execution.profileId,
      profileLabel: execution.profileLabel,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      passed: true,
    );
  }
}

void main() {
  group('QaSuiteRegistry Tests', () {
    setUp(() {
      QaSuiteRegistry.instance.reset();
    });

    test('registers and retrieves test suite definitions polymorphically', () {
      const loginSuite = _MockSuiteDefinition(
        id: QaSuiteId.loginTerminal,
        title: 'Login & Terminal',
        description: 'Login automation suite',
        isImplemented: true,
      );

      QaSuiteRegistry.instance.register(loginSuite);

      final retrieved = QaSuiteRegistry.instance.get(QaSuiteId.loginTerminal);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals(QaSuiteId.loginTerminal));
      expect(retrieved.title, equals('Login & Terminal'));
      expect(QaSuiteRegistry.instance.getAll().length, equals(1));
    });

    test('reset clears all registered suites', () {
      const loginSuite = _MockSuiteDefinition(
        id: QaSuiteId.loginTerminal,
        title: 'Login & Terminal',
        description: 'Login automation suite',
        isImplemented: true,
      );

      QaSuiteRegistry.instance.register(loginSuite);
      expect(QaSuiteRegistry.instance.getAll().length, equals(1));

      QaSuiteRegistry.instance.reset();
      expect(QaSuiteRegistry.instance.getAll().isEmpty, isTrue);
    });
  });
}
