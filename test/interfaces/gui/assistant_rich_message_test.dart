import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_message_list.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_rich_message.dart';

void main() {
  Widget host(AiRichContent content) => MaterialApp(
    home: Scaffold(body: AssistantRichMessage(content: content)),
  );

  testWidgets('preparation activity expands safe lifecycle steps inline', (
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

    expect(find.text('Preparation activity · 3 checks'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.text('Preparation activity · 3 checks'));
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

  testWidgets('keeps completed activity expandable below a knowledge result', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantMessageList(
            messages: <AiChatMessage>[
              AiChatMessage(
                role: AiChatRole.assistant,
                text: 'Here is the login flow.',
                richContent: const AiRichKnowledgeAnswer(
                  answer: AiKnowledgeAnswer(
                    title: 'Login flow',
                    summary: 'Login coverage.',
                  ),
                ),
                activitySummary: const AiRichPlanningSummary(
                  steps: <String>[
                    'Reading QA request…',
                    'Matched Login & Terminal coverage.',
                  ],
                  elapsedMs: 2200,
                ),
              ),
            ],
            scrollController: scrollController,
          ),
        ),
      ),
    );

    expect(find.text('Worked for 2s · 2 checks'), findsOneWidget);
    expect(find.text('Reading QA request…'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Worked for 2s · 2 checks')).dy,
      lessThan(tester.getTopLeft(find.text('Login flow')).dy),
    );

    await tester.tap(find.text('Worked for 2s · 2 checks'));
    await tester.pumpAndSettle();

    expect(find.text('Reading QA request…'), findsOneWidget);
    expect(find.text('Matched Login & Terminal coverage.'), findsOneWidget);
  });

  testWidgets('knowledge answer progressively reveals a safe flow chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiRichKnowledgeAnswer(
          answer: AiKnowledgeAnswer(
            title: 'Login flow',
            summary: 'Login coverage.',
            sections: <AiKnowledgeSection>[
              AiKnowledgeSection(
                title: 'Test cases',
                items: <String>['Login Validation'],
              ),
            ],
            diagrams: <AiKnowledgeDiagram>[
              AiKnowledgeDiagram(
                title: 'Login flow chart',
                nodes: <AiKnowledgeDiagramNode>[
                  AiKnowledgeDiagramNode(
                    id: 'validate',
                    label: 'Login Validation',
                    kind: AiKnowledgeDiagramNodeKind.decision,
                  ),
                  AiKnowledgeDiagramNode(
                    id: 'valid_login',
                    label: 'Valid Login Flow',
                    kind: AiKnowledgeDiagramNodeKind.end,
                  ),
                ],
                edges: <AiKnowledgeDiagramEdge>[
                  AiKnowledgeDiagramEdge(
                    fromNodeId: 'validate',
                    toNodeId: 'valid_login',
                    label: 'Yes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Login flow'), findsOneWidget);
    expect(find.text('Login flow chart'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Login Validation'), findsNWidgets(2));
    expect(find.text('Login flow chart'), findsOneWidget);
    expect(find.text('Valid Login Flow'), findsOneWidget);
    expect(find.text('DECISION'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });
}
