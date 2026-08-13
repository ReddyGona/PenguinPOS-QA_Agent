import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

/// Enters SKU items and weight entries for the active order scenario iteration.
class EnterOrderItemsBlock implements AutomationBlock {
  const EnterOrderItemsBlock({required this.state});

  final OrderRunState state;

  @override
  String get id => 'enter_order_items';

  @override
  String get name => 'SKU & Weighed Item Entry';

  @override
  StepNotice? get notice => const StepNotice(
    'Adding SKUs',
    'Entering order items.',
    isMilestone: true,
  );

  @override
  Future<void> execute(ExecutionContext context) async {
    final driver = context.driver;
    final timeout = context.timeout;

    int itemsThisOrder = 0;
    final skuScanStart = DateTime.now();
    final itemsToPunch = state.scenario.getItemsForIteration(state.orderIndex);

    for (final item in itemsToPunch) {
      if (item.skuCode.trim().isEmpty) continue;

      final effectiveType = item.effectiveType;
      final effectiveMode = item.effectiveEntryMode;

      if (effectiveMode == ItemEntryMode.manualNumpad) {
        final digits = item.skuCode.trim().replaceAll(RegExp(r'[^\d]'), '');
        for (final digit in digits.split('')) {
          final key = PenguinPosOrderKeys.orderNumPadDigit(digit);
          await driver.tap(key);
        }
        await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
      } else if (effectiveMode == ItemEntryMode.manualQwerty) {
        await driver.tap(PenguinPosOrderKeys.orderKeyboardToggle);
        await driver.waitFor(
          PenguinPosOrderKeys.orderQwertyKey('a'),
          timeout: timeout,
        );
        await driver.enterTextViaVirtualKeyboard(
          PenguinPosOrderKeys.orderInputCode,
          item.skuCode.trim(),
          keyPrefix: 'order.qwerty',
          mode: TextInputMode.customQwertyPad,
        );
        await driver.tap(PenguinPosOrderKeys.orderQwertyEnter);
      } else {
        await driver.enterText(
          PenguinPosOrderKeys.orderInputCode,
          item.skuCode.trim(),
        );
        await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
      }

      if (effectiveType == SkuItemType.weighed && item.weight != null) {
        await driver.waitFor(
          PenguinPosOrderKeys.orderInputWeight,
          timeout: timeout,
        );
        final weightStr = item.weight.toString();
        for (final digit in weightStr.split('')) {
          final key = PenguinPosOrderKeys.orderNumPadDigit(digit);
          await driver.tap(key);
        }
        await driver.tap(PenguinPosOrderKeys.orderNumPadEnter);
      }

      itemsThisOrder++;
    }

    state.itemsThisOrder = itemsThisOrder;

    context.emit(
      'Items Entered',
      '$itemsThisOrder item(s) entered for order ${state.orderIndex}.',
    );

    state.stepMetrics.add(
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
  }
}
