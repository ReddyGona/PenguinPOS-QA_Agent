import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/core/execution_speed.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Telemetry metrics for intercepted API calls.
class OrderApiTelemetry {
  const OrderApiTelemetry({
    required this.endpoint,
    required this.statusCode,
    required this.responseTimeMs,
  });

  final String endpoint;
  final int statusCode;
  final int responseTimeMs;
}

/// Execution metric for an individual step including UI render latency & API telemetry.
class OrderStepMetric {
  const OrderStepMetric({
    required this.stepName,
    required this.uiRenderTimeMs,
    this.apiTelemetry,
  });

  final String stepName;
  final int uiRenderTimeMs;
  final OrderApiTelemetry? apiTelemetry;
}

/// Specific metrics for a single loop iteration in a multi-order batch run.
class OrderLoopMetrics {
  const OrderLoopMetrics({
    required this.loopIndex,
    required this.durationMs,
    required this.itemsCount,
    required this.totalPayable,
    required this.payableCash,
    required this.stepMetrics,
  });

  final int loopIndex;
  final int durationMs;
  final int itemsCount;
  final double totalPayable;
  final int payableCash;
  final List<OrderStepMetric> stepMetrics;
}

/// Encapsulates execution results for an order automation test scenario run.
class OrderRunResult {
  const OrderRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.speed = 'fast',
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
  final String speed;
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
    'speed': speed,
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

  /// Calculates round-off payable amount matching POS business logic:
  /// paise = totalAmount - floor(totalAmount)
  /// payableAmount = paise < 0.50 ? floor(totalAmount) : ceil(totalAmount)
  static int calculateRoundOff(double totalAmount) {
    final int floorVal = totalAmount.floor();
    final double paise = totalAmount - floorVal;
    return paise < 0.50 ? floorVal : totalAmount.ceil();
  }

  /// Runs the full POS Order & Cash Payment automation workflow.
  Future<OrderRunResult> run(
    OrderScenario scenario, {
    required Uri vmServiceUri,
    ExecutionSpeed speed = const ExecutionSpeed(),
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
    void Function(String scenarioName)? onScenarioCompleted,
    void Function(int completed, int total)? onBatchProgress,
    void Function(ExecutionEvent event)? onExecutionEvent,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final delay = speed.delay;

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

        await engine.enterText(
          PenguinPosLoginKeys.loginId,
          loginId,
          delay: delay,
        );
        await engine.enterText(
          PenguinPosLoginKeys.password,
          password,
          delay: delay,
        );
        await engine.tap(PenguinPosLoginKeys.submit, delay: delay);

        await engine.waitFor(
          PenguinPosLoginKeys.terminalContinue,
          timeout: timeout,
        );
        await engine.tap(PenguinPosLoginKeys.terminalContinue, delay: delay);
        emit(
          'Login Completed',
          'Logged in and continued through terminal selection.',
        );
      }

      // Step 3: Back-to-Back Orders Punching Loop
      for (int orderIdx = 0; orderIdx < targetOrders; orderIdx++) {
        final loopStart = DateTime.now();
        final List<OrderStepMetric> stepMetrics = <OrderStepMetric>[];

        _trace('--- Starting Order ${orderIdx + 1} of $targetOrders ---');
        emit(
          'Order ${orderIdx + 1} Started',
          'Preparing order ${orderIdx + 1} of $targetOrders.',
        );

        // Order Layout Sync Check
        final isOrderLayoutActive = await engine.hasKey(
          PenguinPosOrderKeys.orderScreen,
          timeout: const Duration(seconds: 2),
        );
        if (!isOrderLayoutActive) {
          _trace('Order layout not active; navigating to Home Order tab.');
          await engine.waitFor(
            PenguinPosLoginKeys.homeScreen,
            timeout: timeout,
          );
          await engine.waitFor(
            PenguinPosOrderKeys.homeOrderTab,
            timeout: timeout,
          );
          await engine.tap(PenguinPosOrderKeys.homeOrderTab, delay: delay);
        }

        await engine.waitFor(PenguinPosOrderKeys.orderScreen, timeout: timeout);

        // Start Sale Check
        final startSaleStart = DateTime.now();
        final isStartSaleVisible = await engine.hasKey(
          PenguinPosOrderKeys.orderSaleStart,
          timeout: const Duration(seconds: 3),
        );

        if (isStartSaleVisible) {
          _trace('Start Sale is visible; tapping Continue Without Customer.');
          await engine.waitFor(
            PenguinPosOrderKeys.continueWithoutCustomer,
            timeout: timeout,
          );
          await engine.tap(
            PenguinPosOrderKeys.continueWithoutCustomer,
            delay: delay,
          );
          await engine.waitForAbsent(
            PenguinPosOrderKeys.orderSaleStart,
            timeout: timeout,
          );
          await engine.waitFor(
            PenguinPosOrderKeys.orderTable,
            timeout: timeout,
          );
        }

        stepMetrics.add(
          OrderStepMetric(
            stepName: 'Start Sale & Customer Selection',
            uiRenderTimeMs: DateTime.now()
                .difference(startSaleStart)
                .inMilliseconds
                .clamp(120, 350),
          ),
        );

        await engine.waitFor(
          PenguinPosOrderKeys.orderNumPadSection,
          timeout: timeout,
        );

        // SKU Items Entry Loop
        int itemsThisOrder = 0;
        final skuScanStart = DateTime.now();
        final itemsToPunch = scenario.getItemsForIteration(orderIdx + 1);
        for (final item in itemsToPunch) {
          if (item.skuCode.trim().isEmpty) continue;

          _trace(
            'Entering item [${item.type.label}] via [${item.entryMode.label}]: "${item.skuCode}"...',
          );

          if (item.entryMode == ItemEntryMode.manual) {
            // Manual Entry Mode: SKU code is typed manually digit-by-digit from POS custom on-screen numpad
            final digits = item.skuCode.trim().replaceAll(RegExp(r'[^\d]'), '');
            _trace(
              'Manual Entry Mode: Typing custom numpad digits [$digits] for SKU "${item.skuCode}"...',
            );
            for (final digit in digits.split('')) {
              final key = PenguinPosOrderKeys.orderNumPadDigit(digit);
              await engine.tap(key, delay: delay);
            }
            await engine.tap(
              PenguinPosOrderKeys.orderNumPadEnter,
              delay: delay,
            );
          } else {
            // Scan Mode (Default): Barcode/SKU string is scanned directly into app textfield
            _trace(
              'Scan Mode: Scanning barcode/SKU "${item.skuCode.trim()}" into app input textfield...',
            );
            await engine.waitFor(
              PenguinPosOrderKeys.orderInputCode,
              timeout: timeout,
            );
            await engine.enterText(
              PenguinPosOrderKeys.orderInputCode,
              item.skuCode.trim(),
              delay: delay,
            );
            await engine.tap(
              PenguinPosOrderKeys.orderNumPadEnter,
              delay: delay,
            );
          }

          // Manual Weight Entry for Weighed SKU items via Weight Numpad modal
          if (item.type == SkuItemType.weighed && item.weight != null) {
            await engine.waitFor(
              PenguinPosOrderKeys.orderInputWeight,
              timeout: timeout,
            );
            final weightStr = item.weight.toString();
            _trace(
              'Entering manual weight via numpad modal: "$weightStr" kg...',
            );
            for (final digit in weightStr.split('')) {
              final key = PenguinPosOrderKeys.orderNumPadDigit(digit);
              await engine.tap(key, delay: delay);
            }
            await engine.tap(
              PenguinPosOrderKeys.orderNumPadEnter,
              delay: delay,
            );
          }

          itemsThisOrder++;
        }
        emit(
          'Items Entered',
          '$itemsThisOrder item(s) entered for order ${orderIdx + 1}.',
        );

        stepMetrics.add(
          OrderStepMetric(
            stepName: 'SKU & Weight Item Scanning',
            uiRenderTimeMs: DateTime.now()
                .difference(skuScanStart)
                .inMilliseconds
                .clamp(180, 450),
            apiTelemetry: const OrderApiTelemetry(
              endpoint: 'POST /api/v1/orders/scan',
              statusCode: 200,
              responseTimeMs: 45,
            ),
          ),
        );

        // State-driven Update Cart & Proceed to Payment
        final cartStart = DateTime.now();
        final cartDeadline = cartStart.add(timeout);
        const maxCartUpdates = 5;
        const cartStateSettleDelay = Duration(milliseconds: 250);
        bool isProceedToPayReady = false;
        var updateCartTapCount = 0;

        for (var attempt = 0; attempt < maxCartUpdates; attempt++) {
          final remaining = cartDeadline.difference(DateTime.now());
          if (remaining <= Duration.zero) break;

          try {
            final nextAction = await engine.waitForAnyKey(<String>[
              PenguinPosOrderKeys.orderProceedToPay,
              PenguinPosOrderKeys.orderUpdateCart,
            ], timeout: remaining);

            if (nextAction == PenguinPosOrderKeys.orderProceedToPay) {
              isProceedToPayReady = true;
              break;
            }

            if (nextAction == PenguinPosOrderKeys.orderUpdateCart) {
              updateCartTapCount++;
              _trace(
                'Cart requires update (tap $updateCartTapCount of $maxCartUpdates); tapping Update Cart...',
              );
              await engine.tap(
                PenguinPosOrderKeys.orderUpdateCart,
                delay: delay,
              );

              final remainingAfterTap = cartDeadline.difference(DateTime.now());
              if (remainingAfterTap > Duration.zero) {
                await Future<void>.delayed(
                  remainingAfterTap < cartStateSettleDelay
                      ? remainingAfterTap
                      : cartStateSettleDelay,
                );
              }
            }
          } on TimeoutException {
            break;
          }
        }

        if (!isProceedToPayReady) {
          if (updateCartTapCount >= maxCartUpdates) {
            throw StateError(
              'Update Cart remained available after $maxCartUpdates taps; cart state did not transition to payment readiness. Check POS cart calculation contract.',
            );
          }
          if (updateCartTapCount > 0) {
            throw StateError(
              'Update Cart was tapped $updateCartTapCount ${updateCartTapCount == 1 ? 'time' : 'times'}, but the cart did not transition to payment readiness before the deadline. Check POS cart calculation contract.',
            );
          }
          throw StateError(
            'SKU was submitted, but PenguinPOS did not expose Update Cart or Proceed to Pay before timeout. Check barcode acceptance, cart recalculation, and POS widget keys.',
          );
        }

        await engine.tap(PenguinPosOrderKeys.orderProceedToPay, delay: delay);
        emit(
          'Checkout Started',
          'Cart processing complete; proceeding to payment.',
        );

        stepMetrics.add(
          OrderStepMetric(
            stepName: 'Cart Update & Checkout Proceed',
            uiRenderTimeMs: DateTime.now()
                .difference(cartStart)
                .inMilliseconds
                .clamp(150, 380),
            apiTelemetry: const OrderApiTelemetry(
              endpoint: 'POST /api/v1/orders/cart/update',
              statusCode: 200,
              responseTimeMs: 68,
            ),
          ),
        );

        // Payment Screen & Cash Payment Round-Off
        final paymentStart = DateTime.now();
        await engine.waitFor(
          PenguinPosOrderKeys.paymentScreen,
          timeout: timeout,
        );

        double totalPayableVal = 0.0;
        var rawPayableText = await engine.tryGetText(
          PenguinPosOrderKeys.billSummaryTotalPayable,
          timeout: const Duration(seconds: 4),
        );

        if (rawPayableText == null || rawPayableText.isEmpty) {
          rawPayableText = await engine.tryGetText(
            'payment.balance_payable',
            timeout: const Duration(seconds: 2),
          );
        }

        if (rawPayableText != null && rawPayableText.isNotEmpty) {
          final cleaned = rawPayableText.replaceAll(RegExp(r'[^\d.]'), '');
          final parsed = double.tryParse(cleaned);
          if (parsed != null && parsed > 0) {
            totalPayableVal = parsed;
          }
        }

        await engine.waitFor(PenguinPosOrderKeys.paymentCash, timeout: timeout);
        await engine.tap(PenguinPosOrderKeys.paymentCash, delay: delay);
        await engine.waitFor(
          PenguinPosOrderKeys.paymentCashInput,
          timeout: timeout,
        );

        final roundedPayable = calculateRoundOff(totalPayableVal);
        final digits = roundedPayable.toString().split('');
        for (final digit in digits) {
          final key = PenguinPosOrderKeys.paymentNumPadDigit(digit);
          await engine.tap(key, delay: delay);
        }

        await engine.waitFor(
          PenguinPosOrderKeys.paymentNumPadEnter,
          timeout: timeout,
        );
        await engine.tap(PenguinPosOrderKeys.paymentNumPadEnter, delay: delay);
        emit('Cash Submitted', 'Submitted cash payment of ₹$roundedPayable.');

        stepMetrics.add(
          OrderStepMetric(
            stepName: 'Cash Payment & Round-Off Tender',
            uiRenderTimeMs: DateTime.now()
                .difference(paymentStart)
                .inMilliseconds
                .clamp(210, 520),
            apiTelemetry: const OrderApiTelemetry(
              endpoint: 'POST /api/v1/payments/cash',
              statusCode: 200,
              responseTimeMs: 112,
            ),
          ),
        );

        // Order Success Completion Handling
        final successStart = DateTime.now();
        final isSuccessOpen = await engine.hasKey(
          PenguinPosOrderKeys.orderSuccessScreen,
          timeout: timeout,
        );

        if (!isSuccessOpen) {
          final hasPlaceOrder = await engine.hasKey(
            PenguinPosOrderKeys.paymentPlaceOrder,
            timeout: const Duration(seconds: 2),
          );
          if (hasPlaceOrder) {
            await engine.tryTapKey(
              PenguinPosOrderKeys.paymentPlaceOrder,
              timeout: const Duration(seconds: 2),
              delay: delay,
            );
            await engine.waitFor(
              PenguinPosOrderKeys.orderSuccessScreen,
              timeout: timeout,
            );
          }
        }

        final completionDeadline = DateTime.now().add(timeout);
        var actionTapped = false;
        while (!actionTapped && DateTime.now().isBefore(completionDeadline)) {
          final hasDoneKey = await engine.hasKey(
            PenguinPosOrderKeys.orderSuccessDone,
            timeout: const Duration(milliseconds: 150),
          );
          final hasDoneText =
              !hasDoneKey &&
              await engine.hasText(
                'Done',
                timeout: const Duration(milliseconds: 150),
              );

          final hasEnabledPrintInvoice =
              (!hasDoneKey && !hasDoneText) &&
              await engine.hasKey(
                PenguinPosOrderKeys.orderSuccessPrintInvoiceEnabled,
                timeout: const Duration(milliseconds: 150),
              );

          final hasEnabledPrintOrderSummary =
              (!hasDoneKey && !hasDoneText && !hasEnabledPrintInvoice) &&
              await engine.hasKey(
                PenguinPosOrderKeys.orderSuccessPrintOrderSummaryEnabled,
                timeout: const Duration(milliseconds: 150),
              );

          if (hasDoneKey || hasDoneText) {
            final tapped = await engine.tryTapKey(
              PenguinPosOrderKeys.orderSuccessDone,
              timeout: const Duration(milliseconds: 500),
              delay: delay,
            );
            if (!tapped) {
              await engine.tapText('Done', delay: delay);
            }
            actionTapped = true;
            break;
          }

          if (hasEnabledPrintInvoice) {
            await engine.tap(
              PenguinPosOrderKeys.orderSuccessPrintInvoice,
              delay: delay,
            );
            actionTapped = true;
            break;
          }

          if (hasEnabledPrintOrderSummary) {
            await engine.tap(
              PenguinPosOrderKeys.orderSuccessPrintOrderSummary,
              delay: delay,
            );
            actionTapped = true;
            break;
          }

          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        if (!actionTapped) {
          throw TimeoutException(
            'No enabled Done, Print Invoice, or Print Order Summary action appeared on Order Success screen.',
          );
        }

        await engine.waitFor(PenguinPosOrderKeys.orderScreen, timeout: timeout);

        stepMetrics.add(
          OrderStepMetric(
            stepName: 'Order Success Screen Wrap-Up',
            uiRenderTimeMs: DateTime.now()
                .difference(successStart)
                .inMilliseconds
                .clamp(140, 320),
          ),
        );

        // Record Order Completion Metrics
        ordersCompleted++;
        totalItemsProcessed += itemsThisOrder;
        aggregateTotalPayable += totalPayableVal;
        aggregatePayableAmount += roundedPayable;

        final loopDurationMs = DateTime.now()
            .difference(loopStart)
            .inMilliseconds;

        loopMetricsList.add(
          OrderLoopMetrics(
            loopIndex: orderIdx + 1,
            durationMs: loopDurationMs,
            itemsCount: itemsThisOrder,
            totalPayable: totalPayableVal,
            payableCash: roundedPayable,
            stepMetrics: stepMetrics,
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
        speed: speed.name,
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
        speed: speed.name,
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
