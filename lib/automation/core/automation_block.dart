import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';

/// Contract for atomic, reusable UI test automation blocks.
abstract class AutomationBlock {
  /// Unique key for diagnostics & tracking
  String get id;

  /// Human-readable step title emitted during execution
  String get name;

  /// Executes the block's atomic automation actions against [context.driver].
  Future<void> execute(ExecutionContext context);
}
