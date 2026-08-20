import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_keys.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

class StatefulFakeDriverEngine extends DriverEngine {
  StatefulFakeDriverEngine({
    required Set<String> initialKeys,
    this.tappedKeys,
    this.onTapKey,
  }) : _availableKeys = Set<String>.from(initialKeys);

  final Set<String> _availableKeys;
  final List<String>? tappedKeys;
  final void Function(String key, Set<String> currentKeys)? onTapKey;

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {}

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    return _availableKeys.contains(key);
  }

  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final key in keys) {
        if (_availableKeys.contains(key)) {
          return key;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException(
      'Timed out waiting for one of: ${keys.join(', ')}.',
      timeout,
    );
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_availableKeys.contains(key)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException('Timed out waiting for key: $key', timeout);
  }

  @override
  Future<void> tap(String key) async {
    tappedKeys?.add(key);
    onTapKey?.call(key, _availableKeys);
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_availableKeys.contains(key)) {
      tappedKeys?.add(key);
      onTapKey?.call(key, _availableKeys);
      return true;
    }
    return false;
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    tappedKeys?.add('enterText:$key:$text');
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return '100.00';
  }
}

void main() {
  group('OrderRunner State-Driven Cart Sync Tests', () {
    const scenario = OrderScenario(
      id: 'cart_sync_test',
      name: 'Cart Sync Test',
      items: <OrderItem>[OrderItem(skuCode: '22')],
    );

    Set<String> baseOrderKeys() => <String>{
      PenguinPosOrderKeys.orderScreen,
      PenguinPosOrderKeys.orderTable,
      PenguinPosOrderKeys.orderNumPadSection,
      PenguinPosOrderKeys.orderInputCode,
      PenguinPosOrderKeys.orderNumPadEnter,
      PenguinPosOrderKeys.paymentScreen,
      PenguinPosOrderKeys.billSummaryTotalPayable,
      PenguinPosOrderKeys.paymentCash,
      PenguinPosOrderKeys.paymentCashInput,
      PenguinPosOrderKeys.paymentNumPadEnter,
      PenguinPosOrderKeys.paymentPlaceOrder,
      PenguinPosOrderKeys.orderSuccessScreen,
      PenguinPosOrderKeys.orderSuccessDone,
    };

    test(
      '1. Proceeds to pay immediately when orderProceedToPay is available',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..add(PenguinPosOrderKeys.orderProceedToPay);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(tapped, contains(PenguinPosOrderKeys.orderProceedToPay));
      },
    );

    test(
      'scan-mode Bizerba uses automatic text entry and the order submit control',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()
          ..add(PenguinPosOrderKeys.orderProceedToPay);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );
        const bizerbaScenario = OrderScenario(
          id: 'bizerba_scan_transport',
          name: 'Bizerba Scan Transport',
          items: <OrderItem>[
            OrderItem(skuCode: '10000001W3.709', type: SkuItemType.bizerba),
          ],
        );

        final result = await PenguinPosOrderRunner().run(
          bizerbaScenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(
          tapped,
          contains(
            'enterText:${PenguinPosOrderKeys.orderInputCode}:10000001W3.709',
          ),
        );
        expect(tapped, contains(PenguinPosOrderKeys.orderNumPadEnter));
      },
    );

    test(
      '2. Statefully transitions from Update Cart to Proceed to Pay',
      () async {
        final tapped = <String>[];
        final keys = baseOrderKeys()..add(PenguinPosOrderKeys.orderUpdateCart);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
          onTapKey: (tappedKey, currentKeys) {
            if (tappedKey == PenguinPosOrderKeys.orderUpdateCart) {
              currentKeys.remove(PenguinPosOrderKeys.orderUpdateCart);
              currentKeys.add(PenguinPosOrderKeys.orderProceedToPay);
            }
          },
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
        );

        expect(result.passed, isTrue);
        expect(tapped, contains(PenguinPosOrderKeys.orderUpdateCart));
        expect(tapped, contains(PenguinPosOrderKeys.orderProceedToPay));
      },
    );

    test(
      '3. Emits 5-tap stale loop diagnostic when Update Cart remains available 5 times',
      () async {
        final events = <ExecutionEvent>[];
        final tapped = <String>[];
        final keys = baseOrderKeys()..add(PenguinPosOrderKeys.orderUpdateCart);
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(seconds: 5),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        final updateCartTaps = tapped
            .where((k) => k == PenguinPosOrderKeys.orderUpdateCart)
            .length;
        expect(updateCartTaps, equals(5));
        expect(
          events.any(
            (e) => e.message.contains(
              'Update Cart remained available after 5 taps; cart state did not transition to payment readiness',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '4. Emits 0-tap timeout diagnostic when neither action appears',
      () async {
        final events = <ExecutionEvent>[];
        final keys =
            baseOrderKeys(); // contains neither updateCart nor proceedToPay
        final engine = StatefulFakeDriverEngine(initialKeys: keys);

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(milliseconds: 100),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        expect(
          events.any(
            (e) => e.message.contains(
              'SKU was submitted, but PenguinPOS did not expose Update Cart or Proceed to Pay before timeout',
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      '5. Waits for cart recalculation before reporting a partial-transition timeout',
      () async {
        final events = <ExecutionEvent>[];
        final tapped = <String>[];
        final keys = baseOrderKeys()..add(PenguinPosOrderKeys.orderUpdateCart);

        var tapCount = 0;
        final engine = StatefulFakeDriverEngine(
          initialKeys: keys,
          tappedKeys: tapped,
          onTapKey: (tappedKey, currentKeys) {
            if (tappedKey == PenguinPosOrderKeys.orderUpdateCart) {
              tapCount++;
            }
          },
        );

        final runner = PenguinPosOrderRunner();
        final result = await runner.run(
          scenario,
          vmServiceUri: Uri.parse('http://127.0.0.1:8080'),
          driverEngine: engine,
          timeout: const Duration(milliseconds: 700),
          onExecutionEvent: (e) => events.add(e),
        );

        expect(result.passed, isFalse);
        // Do not repeat a stale Update Cart tap while the target is still
        // applying the asynchronous cart calculation.
        expect(tapCount, equals(1));
        expect(
          events.any(
            (e) => e.message.contains(
              'Update Cart was tapped 1 time, but the cart did not transition to payment readiness before the deadline',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}
