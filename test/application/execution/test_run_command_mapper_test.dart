import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_mapper.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_catalogue.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_input_validator.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';

void main() {
  const validator = TestCaseInputValidator();

  test('validates the required JSON command envelope', () {
    const command = TestRunCommand(testCaseId: '', profileId: '');

    expect(
      validator.validate(command, TestCaseCatalogue.loginTerminal),
      containsAll(<String>[
        'Test case ID is required.',
        'Target profile ID is required.',
      ]),
    );
  });

  test('validates nested order items and weighed item contracts', () {
    const command = TestRunCommand(
      testCaseId: 'order_checkout',
      profileId: 'kpn-stage',
      inputs: <String, Object?>{
        'ordersCount': 0,
        'items': <Object?>[
          <String, Object?>{'skuCode': '', 'quantity': 0, 'type': 'weighed'},
        ],
      },
    );

    expect(
      validator.validate(command, TestCaseCatalogue.orderCashCheckout),
      containsAll(<String>[
        'ordersCount must be at least 1.',
        'items[0].skuCode has an invalid format.',
        'items[0].quantity must be at least 1.',
        'items[0].weight is required.',
      ]),
    );
  });

  test('maps a valid JSON order command into an execution plan', () {
    const command = TestRunCommand(
      testCaseId: 'order_checkout',
      profileId: 'kpn-stage',
      inputs: <String, Object?>{
        'ordersCount': 2,
        'items': <Object?>[
          <String, Object?>{
            'skuCode': '10000021',
            'quantity': 3,
            'type': 'nonWeighed',
            'entryMode': 'scan',
          },
          <String, Object?>{
            'skuCode': '10000022',
            'quantity': 1,
            'type': 'weighed',
            'weight': 1.25,
          },
        ],
      },
    );

    final plan = TestRunCommandMapper().map(command);

    expect(plan.suiteId, QaSuiteId.orderCheckout);
    expect(plan.profileId, 'kpn-stage');
    expect(plan.orderConfiguration!.ordersCount, 2);
    expect(plan.orderConfiguration!.items.first.quantity, 3);
    expect(plan.orderConfiguration!.items.last.weight, 1.25);
  });

  test('maps per-order JSON items without losing their iteration mapping', () {
    const command = TestRunCommand(
      testCaseId: 'order_checkout',
      profileId: 'kpn-stage',
      inputs: <String, Object?>{
        'ordersCount': 2,
        'itemStrategy': 'perOrder',
        'perOrderItems': <Object?>[
          <String, Object?>{
            'order': 1,
            'items': <Object?>[
              <String, Object?>{'skuCode': '10000021', 'quantity': 2},
            ],
          },
          <String, Object?>{
            'order': 2,
            'items': <Object?>[
              <String, Object?>{'skuCode': '10000022', 'quantity': 1},
            ],
          },
        ],
      },
    );

    final configuration = TestRunCommandMapper()
        .map(command)
        .orderConfiguration!;

    expect(configuration.itemStrategy, ExecutionItemStrategy.perOrder);
    expect(configuration.perIterationItems[1]!.single.quantity, 2);
    expect(configuration.perIterationItems[2]!.single.skuCode, '10000022');
  });

  test('rejects an unknown test case before execution plan creation', () {
    expect(
      () => TestRunCommandMapper().map(
        const TestRunCommand(testCaseId: 'unknown', profileId: 'kpn-stage'),
      ),
      throwsA(isA<TestRunCommandValidationException>()),
    );
  });
}
