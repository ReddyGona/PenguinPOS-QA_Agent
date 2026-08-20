import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh_app_launcher.dart';

/// Runtime-only credentials resolved by the caller after preflight. They are
/// never included in [ExecutionPlanResult] or any event emitted by this class.
class ExecutionCredentials {
  const ExecutionCredentials({
    required this.loginId,
    required this.password,
    this.unlockPin,
  });

  final String loginId;
  final String password;
  final String? unlockPin;
}

/// A preflight-approved execution request. Constructing this object does not
/// launch PenguinPOS; callers should create it only after a passing preflight.
class PreparedExecution {
  const PreparedExecution({
    required this.plan,
    required this.profileId,
    required this.profileLabel,
    required this.entity,
    required this.environment,
    required this.credentials,
    required this.appRoot,
    required this.flutterExecutable,
    this.targetMode = QaTargetMode.local,
    this.sshConfig,
  });

  final ExecutionPlan plan;
  final String profileId;
  final String profileLabel;
  final String entity;
  final String environment;
  final ExecutionCredentials credentials;
  final String appRoot;
  final String flutterExecutable;
  final QaTargetMode targetMode;
  final QaSshConfig? sshConfig;
}

class ExecutionLaunchRequest {
  const ExecutionLaunchRequest({
    required this.appRoot,
    required this.flutterExecutable,
    required this.entity,
    required this.environment,
    this.sshConfig,
    this.onProgress,
  });

  final String appRoot;
  final String flutterExecutable;
  final String entity;
  final String environment;
  final QaSshConfig? sshConfig;
  final void Function(ExecutionEvent event)? onProgress;
}

typedef ExecutionLauncher =
    Future<LaunchedPenguinPos> Function(ExecutionLaunchRequest request);

typedef LoginSuiteExecutor =
    Future<LoginRunResult> Function(
      LoginScenario scenario, {
      required Uri vmServiceUri,
      void Function(ExecutionEvent event)? onExecutionEvent,
      void Function(String scenarioName)? onScenarioCompleted,
      ApiTraceCollector? telemetryCollector,
    });

typedef OrderSuiteExecutor =
    Future<OrderRunResult> Function(
      OrderScenario scenario, {
      required Uri vmServiceUri,
      void Function(ExecutionEvent event)? onExecutionEvent,
      void Function(String scenarioName)? onScenarioCompleted,
      void Function(int completed, int total)? onBatchProgress,
      ApiTraceCollector? telemetryCollector,
    });

/// UI-neutral listener callbacks. The GUI can transform them into activity
/// messages or progress widgets without becoming part of execution logic.
class ExecutionCallbacks {
  const ExecutionCallbacks({
    this.onEvent,
    this.onScenarioCompleted,
    this.onOrderProgress,
    this.onApiTrace,
    this.onTelemetryWarning,
  });

  final void Function(ExecutionEvent event)? onEvent;
  final void Function(String scenarioName)? onScenarioCompleted;
  final void Function(int completed, int total)? onOrderProgress;

  /// Incremental, already-sanitized target API activity.
  final void Function(ApiTraceEvent trace)? onApiTrace;

  /// Non-fatal telemetry bridge failures. These never change test outcome.
  final void Function(String message)? onTelemetryWarning;
}

/// Safe aggregate order information for a report. It contains no runner or
/// driver handles and can be rendered by either AI or Manual mode.
class ExecutionOrderSummary {
  const ExecutionOrderSummary({
    required this.ordersCompleted,
    required this.ordersTarget,
    required this.totalItemsProcessed,
    required this.aggregateTotalPayable,
    required this.aggregatePayableAmount,
  });

  final int ordersCompleted;
  final int ordersTarget;
  final int totalItemsProcessed;
  final double aggregateTotalPayable;
  final int aggregatePayableAmount;
}

/// One normalized result for either login or order execution.
class ExecutionPlanResult {
  const ExecutionPlanResult({
    required this.plan,
    required this.profileId,
    required this.profileLabel,
    required this.startedAt,
    required this.finishedAt,
    required this.passed,
    this.cancelled = false,
    this.wasAppClosedByUser = false,
    this.completedScenarios = const <String>[],
    this.error,
    this.cleanupPassed,
    this.cleanupDetail,
    this.orderSummary,
    this.orderLoopMetrics = const <OrderLoopMetrics>[],
    this.apiTraces = const <ApiTraceEvent>[],
    this.runnerMetadata = const <String, Object?>{},
  });

  final ExecutionPlan plan;
  final String profileId;
  final String profileLabel;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool passed;
  final bool cancelled;
  final bool wasAppClosedByUser;
  final List<String> completedScenarios;
  final String? error;
  final bool? cleanupPassed;
  final String? cleanupDetail;
  final ExecutionOrderSummary? orderSummary;

  /// Per-order measurements captured by the order runner, never estimates.
  final List<OrderLoopMetrics> orderLoopMetrics;

  /// Complete sanitized API trace snapshot at the execution boundary.
  final List<ApiTraceEvent> apiTraces;

  /// Safe runner state useful to report renderers without exposing drivers.
  final Map<String, Object?> runnerMetadata;

  Duration get duration => finishedAt.difference(startedAt);
}

/// Sole owner of a PenguinPOS process while a GUI execution is active.
///
/// It is intentionally constructed with function adapters so the existing
/// concrete runners remain unchanged and the coordinator stays unit-testable.
class QaExecutionCoordinator {
  QaExecutionCoordinator({
    required ExecutionLauncher launcher,
    required LoginSuiteExecutor loginExecutor,
    required OrderSuiteExecutor orderExecutor,
  }) : _launcher = launcher,
       _loginExecutor = loginExecutor,
       _orderExecutor = orderExecutor;

  factory QaExecutionCoordinator.live({
    PenguinPosAppLauncher? launcher,
    SshAppLauncher? sshLauncher,
    PenguinPosLoginRunner? loginRunner,
    PenguinPosOrderRunner? orderRunner,
  }) {
    final resolvedLauncher = launcher ?? PenguinPosAppLauncher();
    final resolvedSshLauncher = sshLauncher ?? SshAppLauncher();
    final resolvedLoginRunner = loginRunner ?? PenguinPosLoginRunner();
    final resolvedOrderRunner = orderRunner ?? PenguinPosOrderRunner();
    return QaExecutionCoordinator(
      launcher: (request) {
        if (request.sshConfig != null) {
          return resolvedSshLauncher.launch(
            config: request.sshConfig!,
            entity: request.entity,
            env: request.environment,
            onProgress: request.onProgress,
          );
        }
        return resolvedLauncher.launch(
          appRoot: request.appRoot,
          flutterExecutable: request.flutterExecutable,
          entity: request.entity,
          env: request.environment,
        );
      },
      loginExecutor: resolvedLoginRunner.runFullSequence,
      orderExecutor: resolvedOrderRunner.run,
    );
  }

  final ExecutionLauncher _launcher;
  final LoginSuiteExecutor _loginExecutor;
  final OrderSuiteExecutor _orderExecutor;

  LaunchedPenguinPos? _activeLaunch;
  bool _running = false;
  bool _stopRequested = false;

  bool get isRunning => _running;

  /// Requests cancellation by closing only the process launched by this
  /// coordinator. Runner completion/cleanup still happens in [run]'s finally.
  Future<void> requestStop() async {
    if (!_running || _stopRequested) return;
    _stopRequested = true;
    await _activeLaunch?.close();
  }

  Future<ExecutionPlanResult> run(
    PreparedExecution execution, {
    ExecutionCallbacks callbacks = const ExecutionCallbacks(),
  }) async {
    if (_running) {
      throw StateError('A QA execution is already running.');
    }
    final planIssues = execution.plan.validate();
    if (planIssues.isNotEmpty) {
      throw ArgumentError.value(
        execution.plan,
        'execution.plan',
        planIssues.first,
      );
    }

    _running = true;
    _stopRequested = false;
    final startedAt = DateTime.now();
    LaunchedPenguinPos? launched;
    final completedScenarios = <String>[];
    final telemetryCollector = ApiTraceCollector(
      onTraceCaptured: callbacks.onApiTrace,
      onTelemetryWarning: callbacks.onTelemetryWarning,
    );

    void scenarioCompleted(String scenarioName) {
      if (!completedScenarios.contains(scenarioName)) {
        completedScenarios.add(scenarioName);
      }
      callbacks.onScenarioCompleted?.call(scenarioName);
    }

    try {
      final isRemote = execution.sshConfig != null;
      void emit(
        String title,
        String message, {
        ExecutionEventLevel level = ExecutionEventLevel.info,
      }) {
        callbacks.onEvent?.call(
          ExecutionEvent(title: title, message: message, level: level),
        );
      }

      emit(
        isRemote ? 'Connecting to SSH Target' : 'Preparing Local Target',
        isRemote
            ? 'Connecting to ${execution.sshConfig!.destination} and preparing its graphical session.'
            : 'Checking the local PenguinPOS runtime before launch.',
      );
      if (!isRemote) {
        emit(
          'Launching PenguinPOS',
          'Starting the local QA application instance.',
        );
        emit(
          'Waiting for Local VM Service',
          'Waiting for PenguinPOS to publish its QA driver endpoint.',
        );
      }
      launched = await _launcher(
        ExecutionLaunchRequest(
          appRoot: execution.appRoot,
          flutterExecutable: execution.flutterExecutable,
          entity: execution.entity,
          environment: execution.environment,
          sshConfig: execution.sshConfig,
          onProgress: callbacks.onEvent,
        ),
      );
      _activeLaunch = launched;
      emit(
        isRemote ? 'Remote PenguinPOS Ready' : 'Local PenguinPOS Ready',
        isRemote
            ? 'SSH tunnel is verified and the remote QA VM service is ready.'
            : 'PenguinPOS started and its QA VM service was discovered.',
        level: ExecutionEventLevel.success,
      );
      emit(
        'Connecting QA Driver',
        'Connecting the automation driver to PenguinPOS.',
      );

      if (_stopRequested) {
        return _cancelledResult(execution, startedAt, completedScenarios);
      }

      if (execution.plan.suiteId == QaSuiteId.loginTerminal) {
        final result = await _loginExecutor(
          LoginScenario(
            id: 'login_terminal_full_sequence',
            name: 'Login and terminal selection',
            loginId: execution.credentials.loginId,
            password: execution.credentials.password,
            unlockPin: execution.credentials.unlockPin,
          ),
          vmServiceUri: launched.vmServiceUri,
          onExecutionEvent: callbacks.onEvent,
          onScenarioCompleted: scenarioCompleted,
          telemetryCollector: telemetryCollector,
        );
        return ExecutionPlanResult(
          plan: execution.plan,
          profileId: execution.profileId,
          profileLabel: execution.profileLabel,
          startedAt: result.startedAt,
          finishedAt: result.finishedAt,
          passed: result.passed && !_stopRequested,
          cancelled: _stopRequested,
          wasAppClosedByUser: result.wasAppClosedByUser || _stopRequested,
          completedScenarios: completedScenarios.isEmpty
              ? List<String>.unmodifiable(result.scenariosExecuted)
              : List<String>.unmodifiable(completedScenarios),
          error: _stopRequested ? _cancelledMessage : result.error,
          cleanupPassed: result.cleanupPassed,
          cleanupDetail: result.cleanupDetail,
          apiTraces: telemetryCollector.capturedTraces,
          runnerMetadata: Map<String, Object?>.unmodifiable(result.metadata),
        );
      }

      final order = execution.plan.orderConfiguration!;
      final result = await _orderExecutor(
        OrderScenario(
          id: '${execution.profileId}_order_cash',
          name: 'Order & Cash Payment',
          loginId: execution.credentials.loginId,
          password: execution.credentials.password,
          unlockPin: execution.credentials.unlockPin,
          items: order.items,
          ordersCount: order.ordersCount,
          inputSourceMode: InputSourceMode.uiForm,
          uiCustomMode: order.itemStrategy == ExecutionItemStrategy.perOrder
              ? UiCustomMode.perIteration
              : UiCustomMode.common,
          perIterationItems: order.perIterationItems,
        ),
        vmServiceUri: launched.vmServiceUri,
        onExecutionEvent: callbacks.onEvent,
        onScenarioCompleted: scenarioCompleted,
        onBatchProgress: callbacks.onOrderProgress,
        telemetryCollector: telemetryCollector,
      );
      return ExecutionPlanResult(
        plan: execution.plan,
        profileId: execution.profileId,
        profileLabel: execution.profileLabel,
        startedAt: result.startedAt,
        finishedAt: result.finishedAt,
        passed: result.passed && !_stopRequested,
        cancelled: _stopRequested,
        wasAppClosedByUser: result.wasAppClosedByUser || _stopRequested,
        completedScenarios: List<String>.unmodifiable(completedScenarios),
        error: _stopRequested ? _cancelledMessage : result.error,
        orderSummary: ExecutionOrderSummary(
          ordersCompleted: result.ordersCompleted,
          ordersTarget: result.ordersTarget,
          totalItemsProcessed: result.totalItemsProcessed,
          aggregateTotalPayable: result.aggregateTotalPayable,
          aggregatePayableAmount: result.aggregatePayableAmount,
        ),
        orderLoopMetrics: List<OrderLoopMetrics>.unmodifiable(
          result.loopMetrics,
        ),
        apiTraces: telemetryCollector.capturedTraces,
        runnerMetadata: Map<String, Object?>.unmodifiable(result.metadata),
      );
    } catch (error) {
      final wasStopped = _stopRequested;
      return ExecutionPlanResult(
        plan: execution.plan,
        profileId: execution.profileId,
        profileLabel: execution.profileLabel,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        passed: false,
        cancelled: wasStopped,
        wasAppClosedByUser: wasStopped || _isAppClosed(error.toString()),
        completedScenarios: List<String>.unmodifiable(completedScenarios),
        error: wasStopped
            ? _cancelledMessage
            : redactSecrets(error.toString(), <String?>[
                execution.credentials.loginId,
                execution.credentials.password,
                execution.credentials.unlockPin,
              ]),
        apiTraces: telemetryCollector.capturedTraces,
      );
    } finally {
      try {
        await launched?.close();
      } catch (_) {}
      if (identical(_activeLaunch, launched)) _activeLaunch = null;
      _running = false;
      telemetryCollector.dispose();
    }
  }

  ExecutionPlanResult _cancelledResult(
    PreparedExecution execution,
    DateTime startedAt,
    List<String> completedScenarios,
  ) => ExecutionPlanResult(
    plan: execution.plan,
    profileId: execution.profileId,
    profileLabel: execution.profileLabel,
    startedAt: startedAt,
    finishedAt: DateTime.now(),
    passed: false,
    cancelled: true,
    wasAppClosedByUser: true,
    completedScenarios: List<String>.unmodifiable(completedScenarios),
    error: _cancelledMessage,
  );

  static const _cancelledMessage = 'Test stopped by the user.';

  static bool _isAppClosed(String error) =>
      error.contains('Service has disappeared') ||
      error.contains('112') ||
      error.contains('SocketException') ||
      error.contains('Closed') ||
      error.contains('exited');
}
