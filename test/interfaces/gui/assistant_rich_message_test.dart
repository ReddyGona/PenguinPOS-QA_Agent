import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_rich_message.dart';

void main() {
  Widget host(AiRichContent content) => MaterialApp(
    home: Scaffold(body: AssistantRichMessage(content: content)),
  );

  testWidgets('planning details reveal safe lifecycle steps only', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiRichPlanningSummary(
          steps: <String>[
            'Parsing request…',
            'Matching target profile…',
            'Validating plan against guardrails…',
          ],
        ),
      ),
    );

    expect(find.text('Planning details'), findsOneWidget);
    expect(find.text('3 steps'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.text('Planning details'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.text('Parsing request…'), findsOneWidget);
    expect(find.text('Matching target profile…'), findsOneWidget);
    expect(find.text('Validating plan against guardrails…'), findsOneWidget);
  });

  testWidgets(
    'order report shows a separate result for every requested order',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AiRichOrderReport(
            suiteTitle: 'Order & Cash Payment',
            profileLabel: 'KPN DEV',
            passed: true,
            totalDurationMs: 3200,
            orders: <AiOrderResult>[
              AiOrderResult(
                orderNumber: 1,
                itemSummary: 'SKU 22 · Non-weighed · Manual entry',
                passed: true,
                durationMs: 1500,
                cashAmount: 40,
              ),
              AiOrderResult(
                orderNumber: 2,
                itemSummary: 'SKU 11 · Non-weighed · Scan',
                passed: true,
                durationMs: 1700,
                cashAmount: 30,
              ),
            ],
            testChecks: <AiScenarioResult>[
              AiScenarioResult(
                name: 'SKU entry accepted',
                passed: true,
                durationMs: 500,
              ),
              AiScenarioResult(
                name: 'Cash payment completed',
                passed: true,
                durationMs: 700,
              ),
            ],
          ),
        ),
      );

      expect(find.text('2 orders completed'), findsOneWidget);
      expect(find.text('Order results'), findsOneWidget);
      expect(find.text('Order 1'), findsOneWidget);
      expect(find.text('Order 2'), findsOneWidget);
      expect(find.textContaining('SKU 22'), findsOneWidget);
      expect(find.textContaining('SKU 11'), findsOneWidget);
      expect(find.text('Test checks applied to every order'), findsOneWidget);
      expect(find.text('SKU entry accepted'), findsOneWidget);
      expect(find.text('Cash payment completed'), findsOneWidget);
    },
  );
}
