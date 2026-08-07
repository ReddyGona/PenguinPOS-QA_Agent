import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/providers/ai_model_provider.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';

class _FixedModelProvider implements AiModelProvider {
  const _FixedModelProvider(this.response);

  final String response;

  @override
  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    AiModelEventCallback? onEvent,
  }) async => response;

  @override
  Future<List<String>> listModels() async => const <String>[];
}

void main() {
  test(
    'normalizes an array-based per-order plan without a type cast crash',
    () {
      final response = AiAssistantResponse.fromJson(<String, Object?>{
        'message': 'Plan ready.',
        'state': 'readyForConfirmation',
        'plan': <Object?>[
          <String, Object?>{
            'workflow': 'orderCashPayment',
            'profileId': 'kpn-stage',
            'ordersCount': 2,
            'itemStrategy': 'perOrder',
            'items': const <Object?>[],
            'perIterationItems': <Object?>[
              <String, Object?>{
                'order': 1,
                'items': <Object?>[
                  <Object?>['22', 'nonWeighed', null, 'manual'],
                ],
              },
              <String, Object?>{
                'order': 2,
                'items': <Object?>[
                  <String, Object?>{
                    'skuCode': '10000001',
                    'type': 'weighed',
                    'weight': 1.763,
                    'entryMode': 'scan',
                  },
                ],
              },
            ],
          },
        ],
      });

      expect(response.plan, isNotNull);
      expect(response.plan!.itemStrategy, AiItemStrategy.perOrder);
      expect(response.plan!.perIterationItems[1]!.single.skuCode, '22');
      expect(
        response.plan!.perIterationItems[1]!.single.entryMode.name,
        'manual',
      );
      expect(response.plan!.perIterationItems[2]!.single.weight, 1.763);
    },
  );

  test(
    'matches profile labels and normalizes them to the configured id',
    () async {
      final response = await AiOrchestrator(
        profiles: <QaProfile>[QaProfile.values.first],
        provider: _FixedModelProvider(
          jsonEncode(<String, Object?>{
            'message': 'Plan ready.',
            'state': 'readyForConfirmation',
            'missingFields': const <String>[],
            'plan': <String, Object?>{
              'workflow': 'orderCashPayment',
              'profileId': 'KPN STAGE',
              'ordersCount': 1,
              'itemStrategy': 'sameForAll',
              'items': <Object?>[
                <String, Object?>{
                  'skuCode': '22',
                  'type': 'nonWeighed',
                  'entryMode': 'manual',
                },
              ],
              'perIterationItems': const <String, Object?>{},
            },
          }),
        ),
      ).respond(input: 'create sku 22', history: <AiChatMessage>[]);

      expect(response.state, AiPlanState.readyForConfirmation);
      expect(response.plan!.profileId, 'kpn-stage');
    },
  );

  test(
    'asks for item details instead of accepting a model-invented SKU default',
    () async {
      final response =
          await AiOrchestrator(
            profiles: <QaProfile>[QaProfile.values.first],
            provider: _FixedModelProvider(
              jsonEncode(<String, Object?>{
                'message': 'Plan ready.',
                'state': 'readyForConfirmation',
                'missingFields': const <String>[],
                'plan': <String, Object?>{
                  'workflow': 'orderCashPayment',
                  'profileId': 'kpn-stage',
                  'ordersCount': 1,
                  'itemStrategy': 'sameForAll',
                  'items': <Object?>[
                    <String, Object?>{
                      'skuCode': '22',
                      'type': 'nonWeighed',
                      'entryMode': 'manual',
                    },
                  ],
                  'perIterationItems': const <String, Object?>{},
                },
              }),
            ),
          ).respond(
            input: 'Can you place one order in kpn dev?',
            history: <AiChatMessage>[],
          );

      expect(response.state, AiPlanState.needsInput);
      expect(response.message, contains('did not specify the SKU'));
      expect(response.missingFields, contains('items'));
    },
  );

  test(
    'allows an explicit repeat request to reuse item details from chat',
    () async {
      final response =
          await AiOrchestrator(
            profiles: <QaProfile>[QaProfile.values.first],
            provider: _FixedModelProvider(
              jsonEncode(<String, Object?>{
                'message': 'Repeating the previous order.',
                'state': 'readyForConfirmation',
                'missingFields': const <String>[],
                'plan': <String, Object?>{
                  'workflow': 'orderCashPayment',
                  'profileId': 'kpn-stage',
                  'ordersCount': 1,
                  'itemStrategy': 'sameForAll',
                  'items': <Object?>[
                    <String, Object?>{
                      'skuCode': '22',
                      'type': 'nonWeighed',
                      'entryMode': 'manual',
                    },
                  ],
                  'perIterationItems': const <String, Object?>{},
                },
              }),
            ),
          ).respond(
            input: 'Repeat the previous order in kpn stage.',
            history: <AiChatMessage>[
              AiChatMessage(
                role: AiChatRole.user,
                text: 'Create SKU 22 as a non-weighed item using manual entry.',
              ),
            ],
          );

      expect(response.state, AiPlanState.readyForConfirmation);
      expect(response.plan!.items.single.skuCode, '22');
    },
  );

  test(
    'blocks a configured production profile before it can execute',
    () async {
      const production = QaProfile(
        id: 'kpn-prod',
        label: 'KPN PROD',
        entity: 'kpn',
        environment: 'production',
      );
      final response = await AiOrchestrator(
        profiles: const <QaProfile>[production],
        provider: _FixedModelProvider(
          jsonEncode(<String, Object?>{
            'message': 'Plan ready.',
            'state': 'readyForConfirmation',
            'missingFields': const <String>[],
            'plan': <String, Object?>{
              'workflow': 'loginFullSequence',
              'profileId': 'kpn-prod',
              'ordersCount': 1,
              'itemStrategy': 'sameForAll',
              'items': const <Object?>[],
              'perIterationItems': const <String, Object?>{},
            },
          }),
        ),
      ).respond(input: 'run in production', history: <AiChatMessage>[]);

      expect(response.state, AiPlanState.unsupported);
      expect(response.message, contains('strictly prohibited'));
    },
  );

  testWidgets('auto-runs a validated plan and keeps status in the chat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var runs = 0;
    final plan = AiTestPlan(
      workflow: AiWorkflow.orderCashPayment,
      profileId: 'kpn-stage',
      items: const <OrderItem>[OrderItem(skuCode: '22')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAssistantWorkspace(
            profiles: QaProfile.values,
            activeProfile: QaProfile.values.first,
            modelConfigured: true,
            running: false,
            activityMessages: const <QaActivityMessage>[],
            executionSteps: const <AiExecutionStep>[],
            executionSuiteTitle: '',
            executionProfileLabel: '',
            onSend: (input, history, onEvent) async {
              onEvent(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Matching target profile…',
                  phase: AiPlanningPhase.matching,
                ),
              );
              onEvent(
                const AiModelEvent(
                  kind: AiModelEventKind.status,
                  message: 'Validating plan against guardrails…',
                  phase: AiPlanningPhase.validating,
                ),
              );
              return AiAssistantResponse(
                message: 'Plan ready.',
                state: AiPlanState.readyForConfirmation,
                plan: plan,
              );
            },
            onRunPlan: (_) => runs++,
            onOpenSettings: () {},
            onExitAiMode: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Create SKU 22');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    expect(runs, 1);
    expect(find.textContaining('Starting execution'), findsOneWidget);
    expect(find.text('Review & Run'), findsNothing);
    expect(find.text('Planning details'), findsOneWidget);

    await tester.tap(find.text('Planning details'));
    await tester.pump();
    expect(find.text('Matching target profile…'), findsOneWidget);
  });
}
