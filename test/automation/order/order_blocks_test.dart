import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/collect_cash_payment_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/complete_order_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/ensure_order_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/enter_order_items_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/start_sale_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/blocks/synchronize_cart_block.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_run_state.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

class FakeOrderDriver implements Driver {
  final List<String> tappedKeys = <String>[];
  final List<String> enteredTexts = <String>[];
  final Map<String, bool> activeKeys = <String, bool>{};
  final Map<String, String> keyTexts = <String, String>{};

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> close() async {}

  @override
  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    for (final key in keys) {
      if (activeKeys[key] == true) return key;
    }
    return keys.first;
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return activeKeys[key] ?? false;
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    return false;
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return keyTexts[key];
  }

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    return keyTexts[key] ?? '';
  }

  @override
  Future<void> tap(String key) async {
    tappedKeys.add(key);
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (activeKeys[key] == true) {
      tappedKeys.add(key);
      return true;
    }
    return false;
  }

  @override
  Future<void> tapText(String text) async {
    tappedKeys.add('text:$text');
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    tappedKeys.add('text:$text');
    return true;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    enteredTexts.add('$key:$text');
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
  }) async {
    enteredTexts.add('$targetInputKey:$text');
  }

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async => 'cleared';

  @override
  Future<bool> clearSnackBars() async => true;

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async => true;

  @override
  Future<bool> clearQaTestNotice() async => true;
}

void main() {
  group('Order Automation Blocks Unit Tests', () {
    late FakeOrderDriver driver;
    late ExecutionContext context;

    setUp(() {
      driver = FakeOrderDriver();
      context = ExecutionContext(
        driver: driver,
        timeout: const Duration(seconds: 5),
      );
    });

    test(
      'EnsureOrderScreenBlock navigates from home tab when orderScreen inactive',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderScreen] = false;

        const block = EnsureOrderScreenBlock();
        await block.execute(context);

        expect(driver.tappedKeys, contains(PenguinPosOrderKeys.homeOrderTab));
      },
    );

    test(
      'StartSaleBlock handles continueWithoutCustomer when start sale is visible',
      () async {
        driver.activeKeys[PenguinPosOrderKeys.orderSaleStart] = true;
        final scenario = const OrderScenario(id: 's1', name: 'Test', items: []);
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = StartSaleBlock(state: state);
        await block.execute(context);

        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.continueWithoutCustomer),
        );
        expect(state.stepMetrics.length, equals(1));
        expect(
          state.stepMetrics.first.stepName,
          equals('Start Sale & Customer Selection'),
        );
      },
    );

    test(
      'EnterOrderItemsBlock enters item SKU and updates state count',
      () async {
        final scenario = const OrderScenario(
          id: 's2',
          name: 'Item Test',
          items: [
            OrderItem(
              skuCode: '101',
              quantity: 2,
              entryMode: ItemEntryMode.manualNumpad,
            ),
          ],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = EnterOrderItemsBlock(state: state);
        await block.execute(context);

        expect(state.itemsThisOrder, equals(2));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadDigit('1')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadDigit('0')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.orderNumPadEnter),
        );
        expect(
          driver.tappedKeys
              .where((key) => key == PenguinPosOrderKeys.orderNumPadEnter)
              .length,
          2,
        );
      },
    );

    test('SynchronizeCartBlock proceeds to pay when ready', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderProceedToPay] = true;
      final scenario = const OrderScenario(
        id: 's3',
        name: 'Cart Test',
        items: [],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      final events = <ExecutionEvent>[];
      final eventContext = ExecutionContext(
        driver: driver,
        timeout: const Duration(seconds: 5),
        onEvent: events.add,
      );

      final block = SynchronizeCartBlock(state: state);
      await block.execute(eventContext);

      expect(
        driver.tappedKeys,
        contains(PenguinPosOrderKeys.orderProceedToPay),
      );
      expect(events.any((e) => e.title == 'Checkout Started'), isTrue);
    });

    test(
      'CollectCashPaymentBlock reads balance, rounds amount, and submits cash',
      () async {
        driver.keyTexts[PenguinPosOrderKeys.billSummaryTotalPayable] =
            '₹150.75';
        final scenario = const OrderScenario(
          id: 's4',
          name: 'Payment Test',
          items: [],
        );
        final state = OrderRunState(orderIndex: 1, scenario: scenario);

        final block = CollectCashPaymentBlock(state: state);
        await block.execute(context);

        expect(state.totalPayableVal, equals(150.75));
        expect(state.roundedPayable, equals(151));
        expect(driver.tappedKeys, contains(PenguinPosOrderKeys.paymentCash));
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadDigit('1')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadDigit('5')),
        );
        expect(
          driver.tappedKeys,
          contains(PenguinPosOrderKeys.paymentNumPadEnter),
        );
      },
    );

    test('CompleteOrderBlock taps done and completes order', () async {
      driver.activeKeys[PenguinPosOrderKeys.orderSuccessScreen] = true;
      driver.activeKeys[PenguinPosOrderKeys.orderSuccessDone] = true;
      final scenario = const OrderScenario(
        id: 's5',
        name: 'Done Test',
        items: [],
      );
      final state = OrderRunState(orderIndex: 1, scenario: scenario);

      final block = CompleteOrderBlock(state: state);
      await block.execute(context);

      expect(driver.tappedKeys, contains(PenguinPosOrderKeys.orderSuccessDone));
      expect(state.stepMetrics.length, equals(1));
    });
  });
}
