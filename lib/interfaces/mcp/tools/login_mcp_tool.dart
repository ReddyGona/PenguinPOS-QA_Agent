import 'package:penguin_pos_qa_agent/application/execution/test_run_command_executor.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_feature_tool.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_definition.dart';
import 'package:penguin_pos_qa_agent/interfaces/mcp/mcp_tool_result.dart';

/// Executes the login test through the common JSON command endpoint.
class LoginFeatureTool implements McpFeatureTool {
  LoginFeatureTool({
    TestRunCommandExecutor? executor,
    QaCredentialVault? credentialVault,
    QaTargetRepository? targetRepository,
  }) : _executor = executor ?? UnifiedTestRunCommandExecutor(),
       _credentialVault = credentialVault ?? QaCredentialVault(),
       _targetRepository = targetRepository ?? QaTargetPreferencesRepository();

  final TestRunCommandExecutor _executor;
  final QaCredentialVault _credentialVault;
  final QaTargetRepository _targetRepository;

  @override
  McpToolDefinition get definition => const McpToolDefinition(
    name: 'penguin_pos_login',
    description:
        'Executes the JSON-first login suite through the unified QA executor. Credentials are stored locally for the selected non-production profile and never returned.',
    inputSchema: <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['profile', 'login_id', 'password'],
      'properties': <String, Object?>{
        'profile': <String, Object?>{
          'type': 'string',
          'enum': <String>[
            'ibo-stage',
            'ibo-dev',
            'kpn-stage',
            'kpn-dev',
            'savomart-stage',
            'savomart-dev',
          ],
          'default': 'ibo-stage',
        },
        'login_id': <String, Object?>{
          'type': 'string',
          'description': '10-digit test login ID.',
        },
        'password': <String, Object?>{
          'type': 'string',
          'description': 'Test password. Never returned.',
        },
        'unlock_pin': <String, Object?>{
          'type': 'string',
          'description':
              'Terminal idle-lock PIN. Required only when the attached app opens with an active idle lock. Never returned.',
        },
        'app_root': <String, Object?>{'type': 'string'},
        'flutter_executable': <String, Object?>{'type': 'string'},
      },
    },
  );

  @override
  Future<McpToolResult> execute(Map<String, Object?> arguments) async {
    final loginId = arguments['login_id'] as String;
    if (!RegExp(r'^\d{10}$').hasMatch(loginId)) {
      return const McpToolResult.failure(
        'login_id must contain exactly 10 digits.',
      );
    }

    try {
      final profileId = arguments['profile'] as String;
      await _credentialVault.write(
        profileId,
        QaStoredCredentials(
          loginId: loginId,
          password: arguments['password'] as String,
          unlockPin: arguments['unlock_pin'] as String? ?? '',
        ),
      );
      final targetMode = await _targetRepository.loadTargetMode(profileId);
      final sshConfig = targetMode == QaTargetMode.ssh
          ? await _targetRepository.loadSshConfig(profileId)
          : null;

      final result = await _executor.executeCommand(
        TestRunCommand(testCaseId: 'login_terminal', profileId: profileId),
        appRoot: arguments['app_root'] as String?,
        flutterExecutable: arguments['flutter_executable'] as String?,
        targetMode: targetMode,
        sshConfig: sshConfig,
      );

      if (!result.passed) {
        return McpToolResult.failure(
          'Login verification failed: ${result.error ?? 'Home screen navigation contract was not fulfilled.'}',
        );
      }
      return McpToolResult.success(<String, Object?>{
        'passed': true,
        'scenarios_executed': result.completedScenarios,
        'profile': result.profileId,
        'started_at': result.startedAt.toUtc().toIso8601String(),
        'finished_at': result.finishedAt.toUtc().toIso8601String(),
      });
    } catch (error) {
      return McpToolResult.failure(error.toString());
    }
  }
}
