import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/automation/core/automation_pipeline.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/collect_cash_payment_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/complete_order_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/ensure_order_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/enter_order_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/start_sale_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/synchronize_cart_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/cash_round_off.dart'
    as order_round_off;
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/session/authentication_pipeline_factory.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Encapsulates execution results for an order automation test scenario run.
class OrderRunResult {
  const OrderRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.ordersCompleted = 0,
    this.ordersTarget = 1,
    this.totalItemsProcessed = 0,
    this.aggregateTotalPayable = 0.0,
    this.aggregatePayableAmount = 0,
    this.loopMetrics = const <OrderLoopMetrics>[],
    this.error,
    this.wasAppClosedByUser = false,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int ordersCompleted;
  final int ordersTarget;
  final int totalItemsProcessed;
  final double aggregateTotalPayable;
  final int aggregatePayableAmount;
  final List<OrderLoopMetrics> loopMetrics;
  final String? error;
  final bool wasAppClosedByUser;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'ordersCompleted': ordersCompleted,
    'ordersTarget': ordersTarget,
    'totalItemsProcessed': totalItemsProcessed,
    'aggregateTotalPayable': aggregateTotalPayable,
    'aggregatePayableAmount': aggregatePayableAmount,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (error != null) 'error': error,
  };
}

/// Executes end-to-end POS order creation & cash payment automation flows.
class PenguinPosOrderRunner {
  void _trace(String message) {
    // ignore: avoid_print
    print('[PenguinPOS QA][order] $message');
    stderr.writeln('[PenguinPOS QA][order] $message');
  }

  /// Calculates round-off payable amount matching POS business logic.
  /// Forwarder method to domain utility [order_round_off.calculateRoundOff].
  static int calculateRoundOff(double totalAmount) =>
      order_round_off.calculateRoundOff(totalAmount);

  /// Runs the full POS Order & Cash Payment automation workflow.
  Future<OrderRunResult> run(
    OrderScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
    void Function(String scenarioName)? onScenarioCompleted,
    void Function(int completed, int total)? onBatchProgress,
    void Function(ExecutionEvent event)? onExecutionEvent,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();

    int ordersCompleted = 0;
    final int targetOrders = scenario.effectiveOrdersCount > 0
        ? scenario.effectiveOrdersCount
        : 1;
    int totalItemsProcessed = 0;
    double aggregateTotalPayable = 0.0;
    int aggregatePayableAmount = 0;

    final List<OrderLoopMetrics> loopMetricsList = <OrderLoopMetrics>[];
    void emit(
      String title,
      String message, {
      ExecutionEventLevel level = ExecutionEventLevel.info,
    }) {
      onExecutionEvent?.call(
        ExecutionEvent(title: title, message: message, level: level),
      );
    }

    try {
      await engine.connect(vmServiceUri, timeout: timeout);
      emit('Driver Connected', 'Connected to PenguinPOS Flutter Driver.');

      final execContext = ExecutionContext(
        driver: engine,
        timeout: timeout,
        onEvent: onExecutionEvent,
      );

      // Step 1 & 2: Initial App state probe (Order Screen, Home, Login)
      _trace('Probing initial UI state (orderScreen, homeScreen, loginId)...');
      final probeStart = DateTime.now();
      final initialState = await engine.waitForAnyKey(<String>[
        PenguinPosOrderKeys.orderScreen,
        PenguinPosLoginKeys.homeScreen,
        PenguinPosLoginKeys.loginId,
      ], timeout: timeout);
      final probeDuration = DateTime.now().difference(probeStart);
      _trace(
        'Initial UI state probed in ${probeDuration.inMilliseconds}ms: "$initialState"',
      );

      // Login prerequisite if app is currently on Login Screen
      if (initialState == PenguinPosLoginKeys.loginId) {
        final loginId = scenario.loginId;
        final password = scenario.password;

        if (loginId == null ||
            loginId.isEmpty ||
            password == null ||
            password.isEmpty) {
          throw StateError(
            'Login credentials are required when app is at Login Screen.',
          );
        }

        final loginScenario = LoginScenario(
          id: 'order_prereq_login',
          name: 'Order Prerequisite Login',
          loginId: loginId,
          password: password,
        );

        final setupBlocks =
            await AuthenticationPipelineFactory.createSetupPipeline(
              execContext,
              loginScenario,
            );

        const pipeline = AutomationPipeline();
        await pipeline.execute(setupBlocks, execContext, emitStepEvents: false);

        emit(
          'Login Completed',
          'Logged in and continued through terminal selection.',
        );
      }

      const pipeline = AutomationPipeline();

      // Step 3: Back-to-Back Orders Punching Loop
      for (int orderIdx = 0; orderIdx < targetOrders; orderIdx++) {
        _trace('--- Starting Order ${orderIdx + 1} of $targetOrders ---');
        emit(
          'Order ${orderIdx + 1} Started',
          'Preparing order ${orderIdx + 1} of $targetOrders.',
        );

        final state = OrderRunState(
          orderIndex: orderIdx + 1,
          scenario: scenario,
        );

        final orderBlocks = [
          const EnsureOrderScreenBlock(),
          StartSaleBlock(state: state),
          EnterOrderItemsBlock(state: state),
          SynchronizeCartBlock(state: state),
          CollectCashPaymentBlock(state: state),
          CompleteOrderBlock(state: state),
        ];

        await pipeline.execute(orderBlocks, execContext, emitStepEvents: false);

        // Record Order Completion Metrics
        ordersCompleted++;
        totalItemsProcessed += state.itemsThisOrder;
        aggregateTotalPayable += state.totalPayableVal;
        aggregatePayableAmount += state.roundedPayable;

        final loopDurationMs = DateTime.now()
            .difference(state.loopStart)
            .inMilliseconds;

        loopMetricsList.add(
          OrderLoopMetrics(
            loopIndex: orderIdx + 1,
            durationMs: loopDurationMs,
            itemsCount: state.itemsThisOrder,
            totalPayable: state.totalPayableVal,
            payableCash: state.roundedPayable,
            stepMetrics: state.stepMetrics,
          ),
        );

        onBatchProgress?.call(ordersCompleted, targetOrders);
        emit(
          'Order ${orderIdx + 1} Completed',
          'Completed $ordersCompleted of $targetOrders orders.',
          level: ExecutionEventLevel.success,
        );
      }

      onScenarioCompleted?.call('Start Sale & Customer Handling');
      onScenarioCompleted?.call('SKU & Weighed Item Entry');
      onScenarioCompleted?.call('Cash Payment & Round-Off');

      return OrderRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        ordersCompleted: ordersCompleted,
        ordersTarget: targetOrders,
        totalItemsProcessed: totalItemsProcessed,
        aggregateTotalPayable: aggregateTotalPayable,
        aggregatePayableAmount: aggregatePayableAmount,
        loopMetrics: loopMetricsList,
      );
    } catch (error) {
      final errorStr = redactSecrets(error.toString(), <String?>[
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ]);
      emit('Order Suite Error', errorStr, level: ExecutionEventLevel.error);
      final isAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');

      return OrderRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        ordersCompleted: ordersCompleted,
        ordersTarget: targetOrders,
        totalItemsProcessed: totalItemsProcessed,
        aggregateTotalPayable: aggregateTotalPayable,
        aggregatePayableAmount: aggregatePayableAmount,
        loopMetrics: loopMetricsList,
        error: errorStr,
        wasAppClosedByUser: isAppClosed,
      );
    } finally {
      await engine.close();
    }
  }
}
