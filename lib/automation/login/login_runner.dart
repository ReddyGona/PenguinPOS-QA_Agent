import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/pipeline_runner.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/ensure_logged_out_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/perform_login_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/select_terminal_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_empty_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/validate_invalid_credentials_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/blocks/verify_home_screen_block.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';

/// Encapsulates execution results for a login scenario run.
class LoginRunResult {
  const LoginRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.scenariosExecuted = const <String>[],
    this.vmServiceUri,
    this.error,
    this.cleanupPassed,
    this.cleanupDetail,
    this.wasAppClosedByUser = false,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<String> scenariosExecuted;
  final Uri? vmServiceUri;
  final String? error;

  /// Post-suite session cleanup is tracked independently so scenario results
  /// remain truthful even when the test environment could not be reset.
  final bool? cleanupPassed;
  final String? cleanupDetail;
  final bool wasAppClosedByUser;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'scenariosExecuted': scenariosExecuted,
    'wasAppClosedByUser': wasAppClosedByUser,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (vmServiceUri != null) 'vmServiceUri': vmServiceUri.toString(),
    if (error != null) 'error': error,
    if (cleanupPassed != null) 'cleanupPassed': cleanupPassed,
    if (cleanupDetail != null) 'cleanupDetail': cleanupDetail,
  };
}

/// Executes login & terminal configuration actions via DriverEngine against a running PenguinPOS instance.
class PenguinPosLoginRunner {
  /// Runs the full sequential login suite using composable automation blocks:
  /// 0. Preflight contract check
  /// 1. Session reset back to Login screen
  /// 2. Empty credentials click validation
  /// 3. Invalid credentials authentication failure check
  /// 4. Valid credentials submission
  /// 5. Terminal selection continue button tap
  /// 6. Home screen navigation verification
  /// 7. Post-login logout cleanup back to LoginScreen
  Future<LoginRunResult> runFullSequence(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    Driver? driverEngine,
    TextInputMode mode = TextInputMode.driverDirect,
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
  }) async {
    final activeDriver = driverEngine ?? DriverEngine();

    // Mode-aware preflight contract verification check
    try {
      await PosAutomationContract.verifyContract(
        activeDriver,
        mode: mode,
        timeout: timeout,
      );
    } catch (_) {
      // Proceed; contract check will also fail softly during execution if keys are absent
    }

    final pipeline = [
      EnsureLoggedOutBlock(),
      ValidateEmptyCredentialsBlock(),
      ValidateInvalidCredentialsBlock(mode: mode),
      PerformLoginBlock(scenario: scenario, mode: mode),
      SelectTerminalBlock(scenario: scenario),
      VerifyHomeScreenBlock(scenario: scenario),
    ];

    final runner = PipelineRunner();
    final res = await runner.runPipeline(
      blocks: pipeline,
      cleanupBlocks: [EnsureLoggedOutBlock()],
      vmServiceUri: vmServiceUri,
      driver: activeDriver,
      timeout: timeout,
      onExecutionEvent: onExecutionEvent,
      onScenarioCompleted: onScenarioCompleted,
      secretsToRedact: [
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ],
    );

    return LoginRunResult(
      passed: res.passed,
      startedAt: res.startedAt,
      finishedAt: res.finishedAt,
      scenariosExecuted: res.scenariosExecuted,
      vmServiceUri: res.vmServiceUri,
      error: res.error,
      cleanupPassed: res.cleanupPassed,
      cleanupDetail: res.cleanupDetail,
      wasAppClosedByUser: res.wasAppClosedByUser,
    );
  }

  /// Runs a single valid login scenario execution.
  Future<LoginRunResult> run(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    Duration timeout = const Duration(seconds: 45),
    Driver? driverEngine,
    TextInputMode mode = TextInputMode.driverDirect,
  }) async {
    final activeDriver = driverEngine ?? DriverEngine();

    final pipeline = [
      EnsureLoggedOutBlock(),
      PerformLoginBlock(scenario: scenario, mode: mode),
      SelectTerminalBlock(scenario: scenario),
      VerifyHomeScreenBlock(scenario: scenario),
    ];

    final runner = PipelineRunner();
    final res = await runner.runPipeline(
      blocks: pipeline,
      cleanupBlocks: [EnsureLoggedOutBlock()],
      vmServiceUri: vmServiceUri,
      driver: activeDriver,
      timeout: timeout,
      secretsToRedact: [
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ],
    );

    return LoginRunResult(
      passed: res.passed,
      startedAt: res.startedAt,
      finishedAt: res.finishedAt,
      scenariosExecuted: res.scenariosExecuted,
      vmServiceUri: res.vmServiceUri,
      error: res.error,
      cleanupPassed: res.cleanupPassed,
      cleanupDetail: res.cleanupDetail,
      wasAppClosedByUser: res.wasAppClosedByUser,
    );
  }
}
