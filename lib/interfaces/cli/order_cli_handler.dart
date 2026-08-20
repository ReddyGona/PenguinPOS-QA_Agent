import 'dart:convert';
import 'dart:io';

import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_executor.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';

/// CLI transport for the JSON-first order checkout automation command.
///
/// Converts command-line flags and arguments into a standard [TestRunCommand]
/// and dispatches it through [TestRunCommandExecutor].
class OrderCliHandler {
  OrderCliHandler({
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
    final profileId = values['profile'] ?? 'kpn-dev';
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

    final ordersCountStr = values['orders-count'] ?? '1';
    final ordersCount = int.tryParse(ordersCountStr) ?? 1;

    final itemsRaw = values['items'];
    List<Map<String, Object?>> items = <Map<String, Object?>>[];

    if (itemsRaw != null && itemsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsRaw);
        if (decoded is List) {
          items = decoded
              .whereType<Map>()
              .map((m) => Map<String, Object?>.from(m))
              .toList();
        }
      } catch (_) {
        // Fallback: SKU string (e.g. "10000021" or "10000021:2")
        final parts = itemsRaw.split(':');
        final sku = parts[0].trim();
        final qty = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
        items = <Map<String, Object?>>[
          <String, Object?>{'skuCode': sku, 'quantity': qty},
        ];
      }
    }

    if (items.isEmpty) {
      // Default standard order item if not provided
      items = <Map<String, Object?>>[
        <String, Object?>{'skuCode': '10000021', 'quantity': 1},
      ];
    }

    final loginId = values['login-id'];
    final password = values['password'];
    final unlockPin = values['unlock-pin'];

    if (loginId != null && password != null) {
      await _credentialVault.write(
        profileId,
        QaStoredCredentials(
          loginId: loginId,
          password: password,
          unlockPin: unlockPin ?? '',
        ),
      );
    }

    try {
      final command = TestRunCommand(
        testCaseId: 'order_checkout',
        profileId: profileId,
        inputs: <String, Object?>{'ordersCount': ordersCount, 'items': items},
      );

      final result = await _executor.executeCommand(
        command,
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
        'Use --profile (e.g. --profile kpn-dev) and configure the target in the QA Agent.',
      );
    }
  }

  Map<String, Object?> _resultJson(
    ExecutionPlanResult result,
  ) => <String, Object?>{
    'passed': result.passed,
    'cancelled': result.cancelled,
    'profile_id': result.profileId,
    'started_at': result.startedAt.toUtc().toIso8601String(),
    'finished_at': result.finishedAt.toUtc().toIso8601String(),
    'completed_scenarios': result.completedScenarios,
    if (result.orderSummary != null)
      'order_summary': <String, Object?>{
        'orders_completed': result.orderSummary!.ordersCompleted,
        'orders_target': result.orderSummary!.ordersTarget,
        'total_items_processed': result.orderSummary!.totalItemsProcessed,
        'aggregate_total_payable': result.orderSummary!.aggregateTotalPayable,
        'aggregate_payable_amount': result.orderSummary!.aggregatePayableAmount,
      },
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
}
