import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';

void main() {
  test('rejects an invalid plan before attempting to launch', () async {
    var launchCalled = false;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) {
        launchCalled = true;
        throw StateError('must not launch');
      },
      loginExecutor:
          (_, {required vmServiceUri, onExecutionEvent, onScenarioCompleted}) =>
              throw UnimplementedError(),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
          }) => throw UnimplementedError(),
    );
    const execution = PreparedExecution(
      plan: ExecutionPlan(profileId: '', suiteId: QaSuiteId.loginTerminal),
      profileId: '',
      profileLabel: '',
      entity: 'kpn',
      environment: 'stage',
      credentials: ExecutionCredentials(loginId: 'id', password: 'password'),
      appRoot: '/app',
      flutterExecutable: 'flutter',
    );

    await expectLater(coordinator.run(execution), throwsArgumentError);
    expect(launchCalled, isFalse);
    expect(coordinator.isRunning, isFalse);
  });
}
