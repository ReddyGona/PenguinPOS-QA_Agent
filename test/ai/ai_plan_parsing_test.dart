import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/providers/ai_model_provider.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';

class _FixedModelProvider implements AiModelProvider {
  const _FixedModelProvider(this.response);

  final String response;

  @override
  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    CancellationToken? cancelToken,
    AiModelEventCallback? onEvent,
  }) async => response;

  @override
  Future<List<String>> listModels() async => const <String>[];
}

class _RecordingModelProvider implements AiModelProvider {
  _RecordingModelProvider(this.response);

  final String response;
  List<AiChatMessage> receivedMessages = const <AiChatMessage>[];

  @override
  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    CancellationToken? cancelToken,
    AiModelEventCallback? onEvent,
  }) async {
    receivedMessages = messages;
    return response;
  }

  @override
  Future<List<String>> listModels() async => const <String>[];
}

void main() {
  test(
    'preserves a raw Bizerba barcode when a configured model asks for details',
    () async {
      final response =
          await AiOrchestrator(
            profiles: QaProfile.values,
            provider: _FixedModelProvider(
              jsonEncode(<String, Object?>{
                'message': 'Please specify the item type and weight.',
                'state': 'needsInput',
                'kind': 'clarification',
                'missingFields': <String>['itemType', 'weight'],
              }),
            ),
          ).respond(
            input: 'punch one order in kpn dev with sku 10000001W3.709',
            history: const <AiChatMessage>[],
          );

      expect(response.canExecute, isTrue);
      expect(response.plan!.profileId, 'kpn-dev');
      final item = response.plan!.items.single;
      expect(item.skuCode, '10000001W3.709');
      expect(item.type, SkuItemType.bizerba);
      expect(item.entryMode, ItemEntryMode.scan);
      expect(item.weight, isNull);
    },
  );

  test(
    'rejects a configured model plan that truncates a raw Bizerba barcode',
    () async {
      final response =
          await AiOrchestrator(
            profiles: QaProfile.values,
            provider: _FixedModelProvider(
              jsonEncode(<String, Object?>{
                'message': 'Plan ready.',
                'state': 'readyForConfirmation',
                'plan': <String, Object?>{
                  'workflow': 'orderCashPayment',
                  'profileId': 'kpn-dev',
                  'ordersCount': 1,
                  'itemStrategy': 'sameForAll',
                  'items': <Object?>[
                    <String, Object?>{
                      'skuCode': '10000001',
                      'type': 'bizerba',
                      'entryMode': 'scan',
                    },
                  ],
                },
              }),
            ),
          ).respond(
            input: 'punch one order in kpn dev with sku 10000001W3.709',
            history: const <AiChatMessage>[],
          );

      expect(response.canExecute, isTrue);
      expect(response.plan!.items.single.skuCode, '10000001W3.709');
      expect(response.plan!.items.single.type, SkuItemType.bizerba);
      expect(response.plan!.items.single.entryMode, ItemEntryMode.scan);
    },
  );

  test(
    'routes an explicit per-order request through the configured model and validates its allocation',
    () async {
      final provider = _RecordingModelProvider(
        jsonEncode(<String, Object?>{
          'message': 'Plan ready.',
          'state': 'readyForConfirmation',
          'plan': <String, Object?>{
            'workflow': 'orderCashPayment',
            'profileId': 'kpn-dev',
            'ordersCount': 3,
            'itemStrategy': 'perOrder',
            'items': const <Object?>[],
            'perIterationItems': <String, Object?>{
              '1': <Object?>[
                <String, Object?>{
                  'skuCode': '22',
                  'type': 'nonWeighed',
                  'entryMode': 'manual',
                },
              ],
              '2': <Object?>[
                <String, Object?>{
                  'skuCode': '11',
                  'type': 'nonWeighed',
                  'entryMode': 'manual',
                },
              ],
              '3': <Object?>[
                <String, Object?>{
                  'skuCode': '10000003.739',
                  'type': 'bizerba',
                  'entryMode': 'scan',
                },
              ],
            },
          },
        }),
      );
      const input =
          'punch 3 orders in kpn dev, each order has custom skus no shared: order 1, sku 22; order 2, sku 11; order 3, sku 10000003.739 bizerba code';

      final response = await AiOrchestrator(
        profiles: QaProfile.values,
        provider: provider,
      ).respond(input: input, history: const <AiChatMessage>[]);

      expect(provider.receivedMessages.last.text, input);
      expect(response.canExecute, isTrue);
      expect(response.plan!.itemStrategy, AiItemStrategy.perOrder);
      expect(response.plan!.perIterationItems[1]!.single.skuCode, '22');
      expect(response.plan!.perIterationItems[2]!.single.skuCode, '11');
      expect(
        response.plan!.perIterationItems[3]!.single.skuCode,
        '10000003.739',
      );
    },
  );

  test('routes standard-item requests through a configured model', () async {
    final provider = _RecordingModelProvider('not valid JSON');

    final response =
        await AiOrchestrator(
          profiles: QaProfile.values,
          provider: provider,
        ).respond(
          input: 'Punch one order in KPN DEV with SKU 22.',
          history: const <AiChatMessage>[],
        );

    expect(provider.receivedMessages, isEmpty);
    expect(response.canExecute, isTrue);
    expect(response.plan!.profileId, 'kpn-dev');
    expect(response.plan!.ordersCount, 1);
  });

  test(
    'blocks model plans with an out-of-range per-order allocation',
    () async {
      final response =
          await AiOrchestrator(
            profiles: QaProfile.values,
            provider: _FixedModelProvider(
              jsonEncode(<String, Object?>{
                'message': 'Plan ready.',
                'state': 'readyForConfirmation',
                'plan': <String, Object?>{
                  'workflow': 'orderCashPayment',
                  'profileId': 'kpn-dev',
                  'ordersCount': 2,
                  'itemStrategy': 'perOrder',
                  'items': const <Object?>[],
                  'perIterationItems': <String, Object?>{
                    '1': <Object?>[
                      <String, Object?>{'skuCode': '22', 'type': 'nonWeighed'},
                    ],
                    '2': <Object?>[
                      <String, Object?>{'skuCode': '11', 'type': 'nonWeighed'},
                    ],
                    '3': <Object?>[
                      <String, Object?>{'skuCode': '44', 'type': 'nonWeighed'},
                    ],
                  },
                },
              }),
            ),
          ).respond(
            input: 'make two separate orders with SKU 22 and SKU 11',
            history: const <AiChatMessage>[],
          );

      expect(response.canExecute, isFalse);
      expect(response.state, AiPlanState.needsInput);
      expect(response.message, contains('exactly one requested order'));
    },
  );

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
        response.plan!.perIterationItems[1]!.single.effectiveEntryMode.name,
        'manualNumpad',
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

  testWidgets('requires review before running a validated plan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var runs = 0;
    final plan = AiTestPlan(
      workflow: AiWorkflow.orderCashPayment,
      profileId: 'kpn-stage',
      items: const <OrderItem>[
        OrderItem(skuCode: '22', entryMode: ItemEntryMode.manualNumpad),
      ],
    );
    final messages = <AiChatMessage>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAssistantWorkspace(
            modelConfigured: true,
            running: false,
            messages: messages,
            onAddMessage: (msg) => messages.add(msg),
            activityMessages: const <QaActivityMessage>[],
            apiTraces: const [],
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
                richContent: const AiRichPlanSummary(
                  profileLabel: 'KPN STAGE',
                  workflowLabel: 'Order & Cash Payment (1 Order)',
                  scenarios: <AiScenarioRow>[
                    AiScenarioRow(name: 'Cash payment'),
                  ],
                  orderItems: <AiOrderItemRow>[
                    AiOrderItemRow(
                      skuCode: '22',
                      typeLabel: 'Non-Weighed',
                      entryModeLabel: 'Manual (Numpad)',
                      allocationLabel: 'All 1 Order',
                    ),
                  ],
                ),
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

    // Validated non-prod plan is automatically triggered
    expect(runs, 1);
    expect(find.textContaining('2 checks'), findsOneWidget);
    expect(find.text('Matching target profile…'), findsOneWidget);
    expect(find.text('Final order allocation'), findsOneWidget);
    expect(find.text('Order 1'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('SKU 22 · Non-Weighed · Manual (Numpad)'), findsOneWidget);
  });
}
