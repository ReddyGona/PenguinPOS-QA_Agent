import 'dart:async';

import 'package:penguin_pos_qa_agent/application/execution/preflight_service.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';

/// Exception thrown when preflight validation fails before execution.
class PreflightValidationException implements Exception {
  const PreflightValidationException({
    required this.failedStepIndex,
    required this.message,
    required this.kind,
  });

  final int failedStepIndex;
  final String message;
  final PreflightCheckKind kind;

  @override
  String toString() =>
      'PreflightValidationException (step $failedStepIndex, $kind): $message';
}

/// Unified service orchestrating preflight checks and test execution across GUI, CLI, and MCP.
class UnifiedExecutionService {
  UnifiedExecutionService({
    QaExecutionCoordinator? coordinator,
    QaCredentialVault? credentialVault,
  }) : _coordinator = coordinator ?? QaExecutionCoordinator.live(),
       _credentialVault = credentialVault ?? QaCredentialVault();

  final QaExecutionCoordinator _coordinator;
  final QaCredentialVault _credentialVault;

  bool get isRunning => _coordinator.isRunning;

  /// Runs full preflight validation. Returns a [PreparedExecution] ready for execution.
  /// Throws [PreflightValidationException] if any validation rule fails.
  Future<PreparedExecution> prepareExecution({
    required ExecutionPlan plan,
    required QaProfile profile,
    String? appRoot,
    String? flutterExecutable,
    QaTargetMode targetMode = QaTargetMode.local,
    QaSshConfig? sshConfig,
  }) async {
    // 1. Profile existence check
    if (profile.id.isEmpty) {
      throw const PreflightValidationException(
        failedStepIndex: 0,
        message: 'The selected target profile is invalid or not found.',
        kind: PreflightCheckKind.profile,
      );
    }

    // 2. Safety Guard: Strict Production Prohibition
    if (profile.isProduction) {
      throw const PreflightValidationException(
        failedStepIndex: 1,
        message:
            'Production environments are strictly prohibited for QA execution.',
        kind: PreflightCheckKind.nonProductionTarget,
      );
    }

    // 3. Vault Credentials Check
    final credentials = await _credentialVault.read(profile.id);
    if (credentials.loginId.isEmpty || credentials.password.isEmpty) {
      throw PreflightValidationException(
        failedStepIndex: 2,
        message:
            'Credentials are required for ${profile.label}. Please save login ID and password.',
        kind: PreflightCheckKind.credentials,
      );
    }

    // 4. SSH Remote Target branch
    if (targetMode == QaTargetMode.ssh) {
      if (sshConfig == null) {
        throw const PreflightValidationException(
          failedStepIndex: 3,
          message: 'SSH configuration is required for remote execution.',
          kind: PreflightCheckKind.runtime,
        );
      }
      final sshIssues = sshConfig.validate();
      if (sshIssues.isNotEmpty) {
        throw PreflightValidationException(
          failedStepIndex: 3,
          message: sshIssues.first,
          kind: PreflightCheckKind.runtime,
        );
      }
      return PreparedExecution(
        plan: plan,
        profileId: profile.id,
        profileLabel: profile.label,
        entity: profile.entity,
        environment: profile.environment,
        credentials: ExecutionCredentials(
          loginId: credentials.loginId,
          password: credentials.password,
          unlockPin: credentials.unlockPin,
        ),
        appRoot: sshConfig.remoteAppRoot,
        flutterExecutable: sshConfig.remoteFlutterExecutable,
        targetMode: QaTargetMode.ssh,
        sshConfig: sshConfig,
      );
    }

    // 5. Local Dynamic Path Resolution & Validation
    final resolvedAppRoot = (appRoot != null && appRoot.trim().isNotEmpty)
        ? appRoot.trim()
        : await PathDetector.detectAppRoot();
    final resolvedFlutter =
        (flutterExecutable != null && flutterExecutable.trim().isNotEmpty)
        ? flutterExecutable.trim()
        : await PathDetector.detectFlutterPath();

    final isAppValid = await PathDetector.isValidAppRoot(resolvedAppRoot);
    final isFlutterValid = await PathDetector.isValidFlutterExecutable(
      resolvedFlutter,
    );

    if (!isAppValid || !isFlutterValid) {
      throw const PreflightValidationException(
        failedStepIndex: 4,
        message: 'PenguinPOS app root or Flutter executable path is invalid.',
        kind: PreflightCheckKind.runtime,
      );
    }

    return PreparedExecution(
      plan: plan,
      profileId: profile.id,
      profileLabel: profile.label,
      entity: profile.entity,
      environment: profile.environment,
      credentials: ExecutionCredentials(
        loginId: credentials.loginId,
        password: credentials.password,
        unlockPin: credentials.unlockPin,
      ),
      appRoot: resolvedAppRoot,
      flutterExecutable: resolvedFlutter,
      targetMode: QaTargetMode.local,
    );
  }

  /// Executes a prepared execution plan.
  Future<ExecutionPlanResult> execute(
    PreparedExecution execution, {
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) {
    return _coordinator.run(execution, callbacks: callbacks);
  }

  /// Requests stop/cancellation of the running test execution.
  Future<void> requestStop() => _coordinator.requestStop();
}
