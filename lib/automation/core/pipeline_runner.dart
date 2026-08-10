import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_run_result.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/core/execution_speed.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Orchestrates execution of an ordered pipeline of [AutomationBlock]s against a target driver session.
class PipelineRunner {
  Future<PipelineRunResult> runPipeline({
    required List<AutomationBlock> blocks,
    required Uri vmServiceUri,
    List<AutomationBlock> cleanupBlocks = const <AutomationBlock>[],
    Driver? driver,
    ExecutionSpeed speed = const ExecutionSpeed(),
    Duration timeout = const Duration(seconds: 45),
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    List<String?> secretsToRedact = const <String?>[],
  }) async {
    final startedAt = DateTime.now();
    final activeDriver = driver ?? DriverEngine();
    final context = ExecutionContext(
      driver: activeDriver,
      speed: speed,
      timeout: timeout,
      onEvent: onExecutionEvent,
    );

    final executed = <String>[];
    var isPassed = true;
    String? errorStr;
    var wasAppClosed = false;

    try {
      await activeDriver.connect(vmServiceUri, timeout: timeout);
      context.emit('Driver Connected', 'Connected to PenguinPOS Driver.');

      for (final block in blocks) {
        context.emit(block.name, 'Executing step...');
        await block.execute(context);
        executed.add(block.name);
        onScenarioCompleted?.call(block.name);
      }
    } catch (error) {
      isPassed = false;
      errorStr = redactSecrets(error.toString(), secretsToRedact);
      context.emit(
        'Pipeline Error',
        errorStr,
        level: ExecutionEventLevel.error,
      );
      wasAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');
    }

    bool? cleanupPassed;
    String? cleanupDetail;

    if (cleanupBlocks.isNotEmpty) {
      try {
        for (final block in cleanupBlocks) {
          await block.execute(context);
        }
        cleanupPassed = true;
        context.emit(
          'Cleanup Completed',
          'Post-pipeline cleanup executed successfully.',
          level: ExecutionEventLevel.success,
        );
      } catch (cleanupError) {
        cleanupPassed = false;
        cleanupDetail = redactSecrets(cleanupError.toString(), secretsToRedact);
        context.emit(
          'Cleanup Warning',
          'Pipeline completed, but cleanup failed. Test isolation is not guaranteed.',
          level: ExecutionEventLevel.error,
        );
      }
    }

    await activeDriver.close();

    return PipelineRunResult(
      passed: isPassed,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      speed: speed.name,
      scenariosExecuted: executed,
      vmServiceUri: vmServiceUri,
      error: errorStr,
      cleanupPassed: cleanupPassed,
      cleanupDetail: cleanupDetail,
      wasAppClosedByUser: wasAppClosed,
    );
  }
}
