import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_executor.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';
import 'package:penguin_pos_qa_agent/interfaces/cli/order_cli_handler.dart';

class _MockCommandExecutor implements TestRunCommandExecutor {
  TestRunCommand? receivedCommand;
  String? receivedAppRoot;
  String? receivedFlutterExecutable;

  @override
  Future<ExecutionPlanResult> executeCommand(
    TestRunCommand command, {
    String? appRoot,
    String? flutterExecutable,
    QaTargetMode targetMode = QaTargetMode.local,
    QaSshConfig? sshConfig,
  }) async {
    receivedCommand = command;
    receivedAppRoot = appRoot;
    receivedFlutterExecutable = flutterExecutable;

    final now = DateTime.utc(2026, 1, 1, 10, 0);
    return ExecutionPlanResult(
      plan: ExecutionPlan(
        profileId: command.profileId,
        suiteId: QaSuiteId.orderCheckout,
      ),
      passed: true,
      cancelled: false,
      profileId: command.profileId,
      profileLabel: 'KPN DEV',
      startedAt: now,
      finishedAt: now.add(const Duration(seconds: 45)),
      completedScenarios: const <String>['Order Execution'],
      orderSummary: const ExecutionOrderSummary(
        ordersCompleted: 2,
        ordersTarget: 2,
        totalItemsProcessed: 4,
        aggregateTotalPayable: 180.0,
        aggregatePayableAmount: 18000,
      ),
    );
  }
}

class _MemoryVault extends QaCredentialVault {
  final Map<String, QaStoredCredentials> store =
      <String, QaStoredCredentials>{};

  @override
  Future<QaStoredCredentials> read(String profileId) async {
    return store[profileId] ?? const QaStoredCredentials();
  }

  @override
  Future<void> write(String profileId, QaStoredCredentials credentials) async {
    store[profileId] = credentials;
  }
}

class _MemoryTargetRepository implements QaTargetRepository {
  @override
  Future<QaTargetMode> loadTargetMode(String profileId) async =>
      QaTargetMode.local;

  @override
  Future<void> saveTargetMode(String profileId, QaTargetMode mode) async {}

  @override
  Future<QaSshConfig?> loadSshConfig(String profileId) async => null;

  @override
  Future<void> saveSshConfig(String profileId, QaSshConfig config) async {}
}

void main() {
  group('OrderCliHandler Tests', () {
    test(
      'parses order options and dispatches order_cash_checkout command',
      () async {
        final mockExecutor = _MockCommandExecutor();
        final vault = _MemoryVault();
        final targetRepo = _MemoryTargetRepository();

        final handler = OrderCliHandler(
          executor: mockExecutor,
          credentialVault: vault,
          targetRepository: targetRepo,
        );

        await handler.execute(<String>[
          '--profile',
          'kpn-dev',
          '--orders-count',
          '2',
          '--items',
          '[{"skuCode":"10000021","quantity":2}]',
          '--app-root',
          '/test/penguin_pos',
        ]);

        expect(mockExecutor.receivedCommand, isNotNull);
        expect(mockExecutor.receivedCommand!.testCaseId, 'order_checkout');
        expect(mockExecutor.receivedCommand!.profileId, 'kpn-dev');
        expect(mockExecutor.receivedCommand!.inputs['ordersCount'], 2);

        final items =
            mockExecutor.receivedCommand!.inputs['items'] as List<dynamic>;
        expect(items.length, 1);
        expect((items.first as Map)['skuCode'], '10000021');
        expect((items.first as Map)['quantity'], 2);
        expect(mockExecutor.receivedAppRoot, '/test/penguin_pos');
      },
    );

    test('accepts single SKU shorthand format', () async {
      final mockExecutor = _MockCommandExecutor();
      final vault = _MemoryVault();
      final targetRepo = _MemoryTargetRepository();

      final handler = OrderCliHandler(
        executor: mockExecutor,
        credentialVault: vault,
        targetRepository: targetRepo,
      );

      await handler.execute(<String>[
        '--profile',
        'ibo-dev',
        '--orders-count',
        '1',
        '--items',
        '10000035:3',
      ]);

      expect(mockExecutor.receivedCommand!.profileId, 'ibo-dev');
      final items =
          mockExecutor.receivedCommand!.inputs['items'] as List<dynamic>;
      expect((items.first as Map)['skuCode'], '10000035');
      expect((items.first as Map)['quantity'], 3);
    });
  });
}
