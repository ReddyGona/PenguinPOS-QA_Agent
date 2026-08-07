import 'package:penguin_pos_qa_agent/core/models.dart';

/// Pass/Fail/Skip status enum for steps and scenarios.
enum ResultStatus { passed, failed, skipped }

/// Execution result for an individual scenario step.
class StepResult {
  const StepResult({
    required this.step,
    required this.status,
    required this.duration,
    this.message,
  });
  final TestStep step;
  final ResultStatus status;
  final Duration duration;
  final String? message;
}

/// Comprehensive execution result for an entire scenario run.
class ScenarioResult {
  const ScenarioResult({
    required this.scenario,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.steps,
    this.failure,
  });
  final TestScenario scenario;
  final ResultStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<StepResult> steps;
  final FailureAnalysis? failure;
}

/// Analysis metadata for failed execution steps.
class FailureAnalysis {
  const FailureAnalysis({
    required this.category,
    required this.confidence,
    required this.recommendation,
  });
  final String category;
  final double confidence;
  final String recommendation;
}
