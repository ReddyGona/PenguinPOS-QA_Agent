import 'dart:async';

import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';

/// Manages cart state transitions, tapping Update Cart when required up to max 5 times, then proceeds to payment.
class SynchronizeCartBlock implements AutomationBlock {
  const SynchronizeCartBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'synchronize_cart';

  @override
  String get name => 'Cart Update & Checkout Proceed';

  @override
  StepNotice? get notice =>
      const StepNotice('Updating cart', 'Synchronizing items.');

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    final cartStart = DateTime.now();
    final cartDeadline = cartStart.add(timeout);
    const maxCartUpdates = 5;
    bool isProceedToPayReady = false;
    var updateCartTapCount = 0;

    for (var attempt = 0; attempt < maxCartUpdates; attempt++) {
      final remaining = cartDeadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      try {
        final nextAction = await driver.waitForAnyKey(<String>[
          PenguinPosOrderKeys.orderProceedToPay,
          PenguinPosOrderKeys.orderUpdateCart,
        ], timeout: remaining);

        if (nextAction == PenguinPosOrderKeys.orderProceedToPay) {
          isProceedToPayReady = true;
          break;
        }

        if (nextAction == PenguinPosOrderKeys.orderUpdateCart) {
          updateCartTapCount++;
          await driver.tap(PenguinPosOrderKeys.orderUpdateCart);
          // Cart recalculation is asynchronous in PenguinPOS.  A fast local
          // driver can observe the old Update Cart button again before Linux
          // has applied the response, leading to five duplicate taps and a
          // false failure over SSH.  Give the target one bounded render turn
          // before probing the next action.
          context.emit(
            'Cart Recalculation',
            'Update Cart requested; waiting for PenguinPOS to refresh checkout readiness.',
          );
          final settleFor = cartDeadline.difference(DateTime.now());
          if (settleFor > Duration.zero) {
            await Future<void>.delayed(
              settleFor < const Duration(milliseconds: 750)
                  ? settleFor
                  : const Duration(milliseconds: 750),
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

    await driver.tap(PenguinPosOrderKeys.orderProceedToPay);
    context.emit(
      'Checkout Started',
      'Cart processing complete; proceeding to payment.',
    );

    state.stepMetrics.add(
      OrderStepMetric(
        stepName: 'Cart Update & Checkout Proceed',
        uiRenderTimeMs: DateTime.now().difference(cartStart).inMilliseconds,
      ),
    );
  }
}
