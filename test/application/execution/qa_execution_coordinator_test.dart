import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';

void main() {
  test('rejects an invalid plan before attempting to launch', () async {
    var launchCalled = false;
    final coordinator = QaExecutionCoordinator(
      launcher: (_) {
        launchCalled = true;
        throw StateError('must not launch');
      },
      loginExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            telemetryCollector,
          }) => throw UnimplementedError(),
      orderExecutor:
          (
            _, {
            required vmServiceUri,
            onExecutionEvent,
            onScenarioCompleted,
            onBatchProgress,
            telemetryCollector,
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

  test(
    'passes a telemetry collector to the runner and preserves report data',
    () async {
      var collectorWasProvided = false;
      final process = await Process.start('sh', const ['-c', 'sleep 10']);
      final coordinator = QaExecutionCoordinator(
        launcher: (_) async => LocalLaunchedPenguinPos(
          process: process,
          vmServiceUri: Uri.parse('http://127.0.0.1:1234/'),
        ),
        loginExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              telemetryCollector,
            }) async {
              collectorWasProvided = telemetryCollector != null;
              onScenarioCompleted?.call('Valid Login Flow');
              return LoginRunResult(
                passed: true,
                startedAt: DateTime.utc(2026, 1, 1),
                finishedAt: DateTime.utc(2026, 1, 1, 0, 0, 2),
                scenariosExecuted: const ['Valid Login Flow'],
                metadata: const {'initial_screen': 'login'},
              );
            },
        orderExecutor:
            (
              _, {
              required vmServiceUri,
              onExecutionEvent,
              onScenarioCompleted,
              onBatchProgress,
              telemetryCollector,
            }) => throw UnimplementedError(),
      );
      const execution = PreparedExecution(
        plan: ExecutionPlan(
          profileId: 'qa-staging',
          suiteId: QaSuiteId.loginTerminal,
        ),
        profileId: 'qa-staging',
        profileLabel: 'QA Staging',
        entity: 'kpn',
        environment: 'staging',
        credentials: ExecutionCredentials(loginId: 'id', password: 'password'),
        appRoot: '/app',
        flutterExecutable: 'flutter',
      );

      final result = await coordinator.run(execution);

      expect(collectorWasProvided, isTrue);
      expect(result.passed, isTrue);
      expect(result.completedScenarios, ['Valid Login Flow']);
      expect(result.runnerMetadata, {'initial_screen': 'login'});
      expect(result.apiTraces, isEmpty);
      expect(result.duration, const Duration(seconds: 2));
    },
  );
}
