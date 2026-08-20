import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_catalogue.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_input_validator.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';

/// Converts the universal JSON command into the runner-neutral execution plan.
class TestRunCommandMapper {
  const TestRunCommandMapper({
    TestCaseCatalogue? catalogue,
    TestCaseInputValidator? validator,
  }) : _catalogue = catalogue,
       _validator = validator;

  final TestCaseCatalogue? _catalogue;
  final TestCaseInputValidator? _validator;

  TestCaseCatalogue get _resolvedCatalogue =>
      _catalogue ?? TestCaseCatalogue.builtIn;
  TestCaseInputValidator get _resolvedValidator =>
      _validator ?? const TestCaseInputValidator();

  ExecutionPlan map(TestRunCommand command) {
    final definition = _resolvedCatalogue.findById(command.testCaseId);
    if (definition == null) {
      throw TestRunCommandValidationException(
        'Unknown test case: ${command.testCaseId}.',
      );
    }
    final issues = _resolvedValidator.validate(command, definition);
    if (issues.isNotEmpty) {
      throw TestRunCommandValidationException(issues.join(' '));
    }

    final plan = switch (definition.runnerTemplateId) {
      'login_terminal' => ExecutionPlan(
        profileId: command.profileId,
        suiteId: QaSuiteId.loginTerminal,
      ),
      'order_checkout' => ExecutionPlan(
        profileId: command.profileId,
        suiteId: QaSuiteId.orderCheckout,
        orderConfiguration: _orderConfiguration(command.inputs),
      ),
      _ => throw TestRunCommandValidationException(
        'Unsupported runner template: ${definition.runnerTemplateId}.',
      ),
    };
    final planIssues = plan.validate();
    if (planIssues.isNotEmpty) {
      throw TestRunCommandValidationException(planIssues.join(' '));
    }
    return plan;
  }

  /// Compatibility-friendly name for transport adapters.
  ExecutionPlan toExecutionPlan(TestRunCommand command) => map(command);

  OrderExecutionConfiguration _orderConfiguration(Map<String, Object?> inputs) {
    final ordersCount = (inputs['ordersCount'] as num).toInt();
    final strategy = inputs['itemStrategy'] == 'perOrder'
        ? ExecutionItemStrategy.perOrder
        : ExecutionItemStrategy.sameForAll;
    final perIterationItems = strategy == ExecutionItemStrategy.perOrder
        ? _perOrderItems(inputs['perOrderItems'])
        : const <int, List<OrderItem>>{};
    return OrderExecutionConfiguration(
      ordersCount: ordersCount,
      itemStrategy: strategy,
      items: strategy == ExecutionItemStrategy.sameForAll
          ? _items(inputs['items'])
          : const <OrderItem>[],
      perIterationItems: perIterationItems,
    );
  }

  List<OrderItem> _items(Object? rawItems) => (rawItems as List<Object?>)
      .whereType<Map>()
      .map((item) => OrderItem.fromJson(item.cast<String, Object?>()))
      .toList(growable: false);

  Map<int, List<OrderItem>> _perOrderItems(Object? rawEntries) {
    final result = <int, List<OrderItem>>{};
    for (final rawEntry in rawEntries as List<Object?>) {
      final entry = (rawEntry as Map).cast<String, Object?>();
      final order = (entry['order'] as num).toInt();
      result[order] = _items(entry['items']);
    }
    return result;
  }
}

/// Raised before preflight when a JSON command cannot be converted safely.
class TestRunCommandValidationException implements Exception {
  const TestRunCommandValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
