import 'dart:convert';
import 'dart:io';

import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_executor.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';

/// CLI transport for the JSON-first login command.
///
/// It may collect credentials interactively, but stores them in the vault
/// before invoking the common executor. Credentials never enter the command
/// payload or a runner-specific API.
class LoginCliHandler {
  LoginCliHandler({
    TestRunCommandExecutor? executor,
    QaCredentialVault? credentialVault,
    QaTargetRepository? targetRepository,
  }) : _executor = executor ?? UnifiedTestRunCommandExecutor(),
       _credentialVault = credentialVault ?? QaCredentialVault(),
       _targetRepository = targetRepository ?? QaTargetPreferencesRepository();

  final TestRunCommandExecutor _executor;
  final QaCredentialVault _credentialVault;
  final QaTargetRepository _targetRepository;

  Future<void> execute(List<String> args) async {
    final values = _readOptions(args);
    final profileId = values['profile'] ?? 'ibo-stage';
    final appRoot = values['app-root'];
    final flutterExecutable = values['flutter-executable'];

    _rejectLegacyTransportOptions(values);

    final sshHost = values['ssh-host'];
    final sshUser = values['ssh-user'];
    final sshPort = int.tryParse(values['ssh-port'] ?? '22') ?? 22;
    final sshKeyPath = values['ssh-key-path'];
    final sshRemoteAppRoot =
        values['ssh-remote-app-root'] ??
        (sshUser != null && sshUser.isNotEmpty
            ? '/home/$sshUser/Documents/penguin_pos'
            : '');
    final sshRemoteFlutter = values['ssh-remote-flutter'] ?? 'flutter';
    final sshRemoteDisplay = values['ssh-remote-display'] ?? ':0';
    final sshVmPort = int.tryParse(values['ssh-vm-port'] ?? '8888') ?? 8888;
    final isExplicitSsh = sshHost != null && sshHost.trim().isNotEmpty;

    QaTargetMode targetMode;
    QaSshConfig? sshConfig;

    if (isExplicitSsh) {
      targetMode = QaTargetMode.ssh;
      sshConfig = QaSshConfig(
        host: sshHost.trim(),
        port: sshPort,
        username: (sshUser != null && sshUser.isNotEmpty)
            ? sshUser.trim()
            : 'savo',
        privateKeyPath: sshKeyPath,
        remoteAppRoot: sshRemoteAppRoot,
        remoteFlutterExecutable: sshRemoteFlutter,
        remoteDisplay: sshRemoteDisplay,
        vmServicePort: sshVmPort,
        launchMethod: values['ssh-launch-method'] == 'flutter_run'
            ? SshLaunchMethod.flutterRun
            : SshLaunchMethod.prebuiltBinary,
      );
    } else {
      // Resolve from profile-scoped target repository
      targetMode = await _targetRepository.loadTargetMode(profileId);
      if (targetMode == QaTargetMode.ssh) {
        sshConfig = await _targetRepository.loadSshConfig(profileId);
      }
    }

    var loginId = values['login-id'];
    var password = values['password'];
    final unlockPin =
        values['unlock-pin'] ?? Platform.environment['PENGUIN_POS_UNLOCK_PIN'];

    if (loginId == null || loginId.trim().isEmpty) {
      stdout.write('Enter Login ID: ');
      loginId = stdin.readLineSync()?.trim();
    }
    if (password == null || password.trim().isEmpty) {
      stdout.write('Enter Password: ');
      password = _readPassword();
    }
    if (loginId == null ||
        loginId.isEmpty ||
        password == null ||
        password.isEmpty) {
      stderr.writeln('Error: Login ID and password are required.');
      exitCode = 64;
      return;
    }

    try {
      await _credentialVault.write(
        profileId,
        QaStoredCredentials(
          loginId: loginId,
          password: password,
          unlockPin: unlockPin ?? '',
        ),
      );
      final result = await _executor.executeCommand(
        TestRunCommand(testCaseId: 'login_terminal', profileId: profileId),
        appRoot: appRoot,
        flutterExecutable: flutterExecutable,
        targetMode: targetMode,
        sshConfig: sshConfig,
      );
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(_resultJson(result)),
      );
      if (!result.passed) exitCode = 1;
    } catch (error) {
      stderr.writeln('Error: $error');
      exitCode = 1;
    }
  }

  void _rejectLegacyTransportOptions(Map<String, String> values) {
    const unsupported = <String>[
      'vm-service-uri',
      'device',
      'entity',
      'env',
      'mode',
    ];
    final selected = unsupported.where(values.containsKey).toList();
    if (selected.isNotEmpty) {
      throw FormatException(
        '${selected.join(', ')} is not supported by the unified executor. '
        'Use --profile and configure the target in the QA Agent instead.',
      );
    }
  }

  Map<String, Object?> _resultJson(ExecutionPlanResult result) =>
      <String, Object?>{
        'passed': result.passed,
        'cancelled': result.cancelled,
        'profile_id': result.profileId,
        'started_at': result.startedAt.toUtc().toIso8601String(),
        'finished_at': result.finishedAt.toUtc().toIso8601String(),
        'completed_scenarios': result.completedScenarios,
        if (result.error != null) 'error': result.error,
      };

  Map<String, String> _readOptions(Iterable<String> args) {
    final values = <String, String>{};
    final iterator = args.iterator;
    while (iterator.moveNext()) {
      final option = iterator.current;
      if (!option.startsWith('--') || !iterator.moveNext()) {
        throw FormatException('Expected a value after $option');
      }
      values[option.substring(2)] = iterator.current;
    }
    return values;
  }

  String? _readPassword() {
    if (stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        final password = stdin.readLineSync()?.trim();
        stdin.echoMode = true;
        stdout.writeln();
        return password;
      } catch (_) {
        stdin.echoMode = true;
      }
    }
    return stdin.readLineSync()?.trim();
  }
}
