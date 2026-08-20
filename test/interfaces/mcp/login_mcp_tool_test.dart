import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_executor.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/tools/login_mcp_tool.dart';

class _RecordingExecutor implements TestRunCommandExecutor {
  TestRunCommand? command;
  String? appRoot;
  String? flutterExecutable;

  @override
  Future<ExecutionPlanResult> executeCommand(
    TestRunCommand next, {
    String? appRoot,
    String? flutterExecutable,
    QaTargetMode targetMode = QaTargetMode.local,
    QaSshConfig? sshConfig,
  }) async {
    command = next;
    this.appRoot = appRoot;
    this.flutterExecutable = flutterExecutable;
    final now = DateTime.utc(2026);
    return ExecutionPlanResult(
      plan: const ExecutionPlan(
        profileId: 'ibo-stage',
        suiteId: QaSuiteId.loginTerminal,
      ),
      profileId: 'ibo-stage',
      profileLabel: 'IBO STAGE',
      startedAt: now,
      finishedAt: now,
      passed: true,
      completedScenarios: const <String>['Valid login'],
    );
  }
}

class _MemoryVault extends QaCredentialVault {
  QaStoredCredentials? saved;

  @override
  Future<void> write(String profileId, QaStoredCredentials credentials) async {
    saved = credentials;
  }
}

class _MemoryTargetRepository implements QaTargetRepository {
  @override
  Future<QaTargetMode> loadTargetMode(String profileId) async =>
      QaTargetMode.local;

  @override
  Future<void> saveTargetMode(String profileId, QaTargetMode mode) async {}

  @override
  Future<QaSshConfig?> loadSshConfig(String profileId) async => null;

  @override
  Future<void> saveSshConfig(String profileId, QaSshConfig config) async {}
}

void main() {
  test(
    'MCP login saves credentials then dispatches the universal JSON command',
    () async {
      final executor = _RecordingExecutor();
      final vault = _MemoryVault();
      final targetRepo = _MemoryTargetRepository();
      final tool = LoginFeatureTool(
        executor: executor,
        credentialVault: vault,
        targetRepository: targetRepo,
      );

      final response = await tool.execute(<String, Object?>{
        'profile': 'ibo-stage',
        'login_id': '1234567890',
        'password': 'secret',
        'unlock_pin': '1234',
        'app_root': '/workspace/penguin_pos',
        'flutter_executable': '/workspace/flutter/bin/flutter',
      });

      expect(response.isError, isFalse);
      expect(executor.command?.toJson(), <String, Object?>{
        'testCaseId': 'login_terminal',
        'profileId': 'ibo-stage',
        'inputs': <String, Object?>{},
      });
      expect(executor.appRoot, '/workspace/penguin_pos');
      expect(vault.saved?.loginId, '1234567890');
      expect(vault.saved?.password, 'secret');
      expect(vault.saved?.unlockPin, '1234');
    },
  );
}
