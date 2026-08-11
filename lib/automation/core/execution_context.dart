import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_collector.dart';

/// Execution context passed to every [AutomationBlock] during test pipeline execution.
class ExecutionContext {
  final Driver driver;
  final Duration timeout;
  final void Function(ExecutionEvent event)? onEvent;
  final ApiTraceCollector? telemetryCollector;

  /// Shared non-sensitive state payload passed between blocks in a pipeline.
  final Map<String, Object?> state = {};

  ExecutionContext({
    required this.driver,
    this.timeout = const Duration(seconds: 45),
    this.onEvent,
    this.telemetryCollector,
  });

  void emit(
    String title,
    String message, {
    ExecutionEventLevel level = ExecutionEventLevel.info,
  }) {
    onEvent?.call(ExecutionEvent(title: title, message: message, level: level));
  }
}
