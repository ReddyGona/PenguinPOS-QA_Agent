import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';

/// Sequentially executes a series of [AutomationBlock]s using an active [ExecutionContext].
/// Does not manage driver connection or teardown.
class AutomationPipeline {
  const AutomationPipeline();

  /// Executes [blocks] sequentially against [context].
  ///
  /// Calls [onScenarioCompleted] with each block's name upon completion if provided.
  /// Returns a list of the block names successfully executed.
  Future<List<String>> execute(
    List<AutomationBlock> blocks,
    ExecutionContext context, {
    void Function(String scenarioName)? onScenarioCompleted,
    bool emitStepEvents = true,
  }) async {
    final executedBlockNames = <String>[];

    for (final block in blocks) {
      final notice =
          block.notice ?? StepNotice(block.name, 'Running ${block.name}.');
      await context.showNotice(
        QaTestNoticeSeverity.info,
        notice.title,
        notice.message,
        isMilestone: notice.isMilestone,
      );
      if (emitStepEvents) {
        context.emit(block.name, 'Executing step...');
      }
      try {
        await context.driver.clearSnackBars();
        final telemetryDispatcher = context.telemetryDispatcher;
        if (telemetryDispatcher != null) {
          telemetryDispatcher.captureStep(block.id);
        } else {
          await context.telemetryCollector?.markStep(context.driver, block.id);
        }
        await block.execute(context);
        if (telemetryDispatcher == null) {
          await context.telemetryCollector?.fetchNewTraces(context.driver);
        }
      } catch (_) {
        await context.showNotice(
          QaTestNoticeSeverity.error,
          '${block.name} failed',
          'The step could not be completed. Check the QA Agent terminal for details.',
        );
        rethrow;
      }
      executedBlockNames.add(block.name);
      onScenarioCompleted?.call(block.name);
    }

    return executedBlockNames;
  }
}
