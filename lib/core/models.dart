/// Supported action types available across QA test steps.
enum StepAction {
  login,
  enterText,
  tap,
  waitFor,
  inspectWidgetTree,
  scan,
  weight,
  loyalty,
  payment,
  verifyReceipt,
  offline,
  sync,
  verify,
}

/// Represents an individual test step declaration with an action and payload.
class TestStep {
  const TestStep({
    required this.action,
    this.payload = const <String, Object?>{},
  });
  final StepAction action;
  final Map<String, Object?> payload;
}

/// Declarative representation of a complete QA test scenario parsed from YAML.
class TestScenario {
  const TestScenario({
    required this.id,
    required this.name,
    required this.steps,
    this.tags = const <String>[],
  });
  final String id;
  final String name;
  final List<TestStep> steps;
  final List<String> tags;
}

/// Execution lifecycle event published during scenario execution.
class ExecutionEvent {
  ExecutionEvent(this.type, this.message, {DateTime? at})
    : at = at ?? DateTime.now();
  final String type;
  final String message;
  final DateTime at;
}
