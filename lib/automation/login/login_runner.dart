import 'dart:async';

import '../../core/execution_speed.dart';
import '../../runtime/driver_engine.dart';
import 'login_keys.dart';
import 'login_scenario.dart';

/// Encapsulates execution results for a login scenario run.
class LoginRunResult {
  const LoginRunResult({
    required this.passed,
    required this.startedAt,
    required this.finishedAt,
    this.speed = 'fast',
    this.scenariosExecuted = const <String>[],
    this.vmServiceUri,
    this.error,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String speed;
  final List<String> scenariosExecuted;
  final Uri? vmServiceUri;
  final String? error;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'speed': speed,
    'scenariosExecuted': scenariosExecuted,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    if (vmServiceUri != null) 'vmServiceUri': vmServiceUri.toString(),
    if (error != null) 'error': error,
  };
}

/// Executes login & terminal configuration actions via DriverEngine against a running PenguinPOS instance.
class PenguinPosLoginRunner {
  /// Runs the full sequential login suite:
  /// 1. Empty credentials click validation
  /// 2. Invalid credentials authentication failure check
  /// 3. Valid credentials submission
  /// 4. Terminal selection continue button tap
  /// 5. Home screen navigation verification
  Future<LoginRunResult> runFullSequence(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    ExecutionSpeed speed = const ExecutionSpeed(),
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final delay = speed.delay;
    final executed = <String>[];

    try {
      await engine.connect(vmServiceUri, timeout: timeout);

      // Phase 1: Empty credentials submit validation check
      await engine.waitFor(
        PenguinPosLoginKeys.loginId,
        timeout: timeout,
        delay: delay,
      );
      await engine.tap(PenguinPosLoginKeys.submit, delay: delay);
      await engine.waitFor(
        PenguinPosLoginKeys.loginId,
        timeout: timeout,
        delay: delay,
      );
      executed.add('empty_credentials_validation');

      // Phase 2: Invalid credentials submit authentication check
      await engine.enterText(
        PenguinPosLoginKeys.loginId,
        '0000000000',
        delay: delay,
      );
      await engine.enterText(
        PenguinPosLoginKeys.password,
        'invalid_password',
        delay: delay,
      );
      await engine.tap(PenguinPosLoginKeys.submit, delay: delay);
      await engine.waitFor(
        PenguinPosLoginKeys.loginId,
        timeout: timeout,
        delay: delay,
      );
      executed.add('invalid_credentials_attempt');

      // Phase 3: Valid credentials submit
      await engine.enterText(
        PenguinPosLoginKeys.loginId,
        scenario.loginId,
        delay: delay,
      );
      await engine.enterText(
        PenguinPosLoginKeys.password,
        scenario.password,
        delay: delay,
      );
      await engine.tap(PenguinPosLoginKeys.submit, delay: delay);

      // Phase 4: Terminal selection screen & continue button tap
      await engine.waitFor(
        scenario.terminalContinueKey,
        timeout: timeout,
        delay: delay,
      );
      await engine.tap(scenario.terminalContinueKey, delay: delay);

      // Phase 5: Wait until app navigates into Home Screen
      await engine.waitFor(
        scenario.expectedKey,
        timeout: timeout,
        delay: delay,
      );
      executed.add('valid_login_terminal_selection_and_home_screen');

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
      );
    } catch (error) {
      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
        error: error.toString(),
      );
    } finally {
      await engine.close();
    }
  }

  /// Runs a single valid login scenario execution.
  Future<LoginRunResult> run(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    ExecutionSpeed speed = const ExecutionSpeed(),
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final delay = speed.delay;

    try {
      await engine.connect(vmServiceUri, timeout: timeout);

      // Step 1: Wait for login screen and enter Login ID
      await engine.waitFor(
        PenguinPosLoginKeys.loginId,
        timeout: timeout,
        delay: delay,
      );
      await engine.enterText(
        PenguinPosLoginKeys.loginId,
        scenario.loginId,
        delay: delay,
      );

      // Step 2: Enter Password
      await engine.enterText(
        PenguinPosLoginKeys.password,
        scenario.password,
        delay: delay,
      );

      // Step 3: Submit login credentials
      await engine.tap(PenguinPosLoginKeys.submit, delay: delay);

      // Step 4: Wait for Terminal Configuration screen & tap Continue button
      await engine.waitFor(
        scenario.terminalContinueKey,
        timeout: timeout,
        delay: delay,
      );
      await engine.tap(scenario.terminalContinueKey, delay: delay);

      // Step 5: Wait until app navigates into Home Screen
      await engine.waitFor(
        scenario.expectedKey,
        timeout: timeout,
        delay: delay,
      );

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: const <String>[
          'valid_login_terminal_selection_and_home_screen',
        ],
        vmServiceUri: vmServiceUri,
      );
    } catch (error) {
      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        vmServiceUri: vmServiceUri,
        error: error.toString(),
      );
    } finally {
      await engine.close();
    }
  }
}
