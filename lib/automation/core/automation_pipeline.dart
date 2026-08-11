import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';

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
      if (emitStepEvents) {
        context.emit(block.name, 'Executing step...');
      }
      await context.driver.clearSnackBars();
      await block.execute(context);
      executedBlockNames.add(block.name);
      onScenarioCompleted?.call(block.name);
    }

    return executedBlockNames;
  }
}
