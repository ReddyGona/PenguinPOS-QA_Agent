import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

void main() {
  AiOrchestrator buildOrchestrator() =>
      AiOrchestrator(profiles: QaProfile.values, provider: null);

  test(
    'retains a non-secret order draft until its strategy is explicit',
    () async {
      final orchestrator = buildOrchestrator();
      final initial = await orchestrator.respond(
        input: 'place 2 orders with SKUs 22, 11 in kpn stage',
        history: const <AiChatMessage>[],
      );
      expect(initial.pendingRequest, isNotNull);
      expect(initial.missingFields, contains('itemStrategy'));
      expect(initial.pendingRequest!.skuCodes, <String>['22', '11']);

      final typed = await orchestrator.respond(
        input: 'those are non-weighed',
        history: const <AiChatMessage>[],
        pendingRequest: initial.pendingRequest,
      );
      final manual = await orchestrator.respond(
        input: 'manual entry',
        history: const <AiChatMessage>[],
        pendingRequest: typed.pendingRequest,
      );
      expect(manual.missingFields, contains('itemStrategy'));

      final ready = await orchestrator.respond(
        input: 'same items for both orders',
        history: const <AiChatMessage>[],
        pendingRequest: manual.pendingRequest,
      );
      expect(ready.canExecute, isTrue);
      expect(ready.plan!.profileId, 'kpn-stage');
      expect(ready.plan!.itemStrategy, AiItemStrategy.sameForAll);
      expect(
        ready.plan!.items.map((item) => item.type),
        everyElement(SkuItemType.nonWeighed),
      );
      expect(
        ready.plan!.items.map((item) => item.entryMode),
        everyElement(ItemEntryMode.manual),
      );
    },
  );

  test(
    'parses raw Bizerba barcode strings and defaults to scan mode',
    () async {
      final orchestrator = buildOrchestrator();
      final response = await orchestrator.respond(
        input: 'place order with bizerba 10000001W2.345 in kpn stage',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan!.items, hasLength(1));
      final item = response.plan!.items.first;
      expect(item.skuCode, '10000001W2.345');
      expect(item.type, SkuItemType.bizerba);
      expect(item.entryMode, ItemEntryMode.scan);
    },
  );

  test(
    'defaults unmentioned items to nonWeighed and manual entry mode',
    () async {
      final orchestrator = buildOrchestrator();
      final response = await orchestrator.respond(
        input: 'place order with SKUs 22, 11 in kpn stage',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan!.items, hasLength(2));
      expect(
        response.plan!.items.map((i) => i.type),
        everyElement(SkuItemType.nonWeighed),
      );
      expect(
        response.plan!.items.map((i) => i.entryMode),
        everyElement(ItemEntryMode.manual),
      );
      expect(response.richContent, isA<AiRichPlanSummary>());
      final rich = response.richContent as AiRichPlanSummary;
      expect(rich.orderItems, hasLength(2));
      expect(rich.orderItems.first.typeLabel, 'Non-Weighed');
      expect(rich.orderItems.first.entryModeLabel, 'Manual (Numpad)');
    },
  );

  test(
    'parses plain-English order wording and defaults safe item fields',
    () async {
      final response = await buildOrchestrator().respond(
        input: 'place an order with sku 22, 11 in kpn dev',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan!.profileId, 'kpn-dev');
      expect(response.plan!.items.map((item) => item.skuCode), <String>[
        '22',
        '11',
      ]);
      expect(
        response.plan!.items.map((item) => item.type),
        everyElement(SkuItemType.nonWeighed),
      );
      expect(
        response.plan!.items.map((item) => item.entryMode),
        everyElement(ItemEntryMode.manual),
      );
    },
  );

  test(
    'classifies mixed bizerba and manual SKUs per-item in a single prompt',
    () async {
      final orchestrator = buildOrchestrator();
      final response = await orchestrator.respond(
        input:
            'punch 3 orders back to back with bizerba sku: 10000001W3.223 in scan mode, '
            'skus: 22, 11 in manual entry non weighted '
            'use same skus for all the 3 orders in kpn staging',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan, isNotNull);
      expect(response.plan!.items, hasLength(3));

      // Bizerba barcode: classified as Bizerba + Scan.
      final bizerba = response.plan!.items.firstWhere(
        (i) => i.skuCode == '10000001W3.223',
      );
      expect(bizerba.type, SkuItemType.bizerba);
      expect(bizerba.entryMode, ItemEntryMode.scan);

      // Short numeric SKUs: classified as Non-Weighed + Manual.
      final sku22 = response.plan!.items.firstWhere((i) => i.skuCode == '22');
      expect(sku22.type, SkuItemType.nonWeighed);
      expect(sku22.entryMode, ItemEntryMode.manual);

      final sku11 = response.plan!.items.firstWhere((i) => i.skuCode == '11');
      expect(sku11.type, SkuItemType.nonWeighed);
      expect(sku11.entryMode, ItemEntryMode.manual);

      // Literal 'sku' must never appear as a SKU code.
      expect(
        response.plan!.items.map((i) => i.skuCode),
        isNot(contains('sku')),
      );
    },
  );

  test(
    'correctly parses order count multiplier phrases such as 3 times',
    () async {
      final orchestrator = buildOrchestrator();
      final response = await orchestrator.respond(
        input:
            'punch one order with sku 22 non weighted manual mode 3 times in kpn dev',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan, isNotNull);
      expect(response.plan!.ordersCount, 3);
      expect(response.plan!.profileId, 'kpn-dev');
      expect(response.plan!.items.first.skuCode, '22');
      expect(response.plan!.items.first.type, SkuItemType.nonWeighed);
      expect(response.plan!.items.first.entryMode, ItemEntryMode.manual);
    },
  );

  test(
    'falls back to active non-prod profile when prompt omits explicit environment',
    () async {
      const kpnDev = QaProfile(
        id: 'kpn-dev',
        label: 'KPN DEV',
        entity: 'kpn',
        environment: 'dev',
      );
      final orchestrator = AiOrchestrator(
        profiles: QaProfile.values,
        activeProfile: kpnDev,
        provider: null,
      );
      final response = await orchestrator.respond(
        input: 'punch 3 orders with sku: 22 in manual mode, non weighted',
        history: const <AiChatMessage>[],
      );

      expect(response.canExecute, isTrue);
      expect(response.plan, isNotNull);
      expect(response.plan!.ordersCount, 3);
      expect(response.plan!.profileId, 'kpn-dev');
      expect(response.plan!.items.first.skuCode, '22');
      expect(response.plan!.items.first.type, SkuItemType.nonWeighed);
      expect(response.plan!.items.first.entryMode, ItemEntryMode.manual);
    },
  );
}
