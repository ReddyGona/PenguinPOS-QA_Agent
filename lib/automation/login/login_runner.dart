import 'package:flutter/foundation.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/core/execution_speed.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';
import 'package:penguin_pos_qa_agent/runtime/driver_engine.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';

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
    this.cleanupPassed,
    this.cleanupDetail,
    this.wasAppClosedByUser = false,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String speed;
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
    'speed': speed,
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
  void _trace(String msg) => debugPrint('[LoginRunner] $msg');

  /// Ensures the app is at Login before starting a suite.
  Future<void> _ensureLoggedOut(
    DriverEngine engine, {
    Duration timeout = const Duration(seconds: 45),
    Duration delay = Duration.zero,
  }) async {
    final initialState = await engine.waitForAnyKey(<String>[
      PenguinPosLoginKeys.loginId,
      PenguinPosLoginKeys.homeScreen,
    ], timeout: timeout);
    _trace('Initial UI state: $initialState');

    if (initialState == PenguinPosLoginKeys.loginId) {
      _trace('App is already on Login; no session reset is needed.');
      return;
    }

    final hasKeyedLogout = await engine.hasKey(
      PenguinPosLoginKeys.logoutButton,
      timeout: const Duration(seconds: 2),
    );
    if (hasKeyedLogout) {
      _trace(
        'Keyed Logout control is visible; opening the confirmation dialog.',
      );
      await engine.tap(PenguinPosLoginKeys.logoutButton, delay: delay);
    } else {
      _trace(
        'logout.button key is unavailable; using the visible LOGOUT label fallback.',
      );
      await engine.tapText('LOGOUT', delay: delay);
    }
    await engine.waitFor(PenguinPosLoginKeys.logoutConfirm, timeout: timeout);
    await engine.tap(PenguinPosLoginKeys.logoutConfirm, delay: delay);
    _trace('Confirmed logout; waiting for Login.');
    await engine.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: timeout,
      delay: delay,
    );
    _trace('Login is visible; session reset completed.');
  }

  /// Runs the full sequential login suite:
  /// 0. Wait for Login, Idle Lock, or Home through the target widget tree.
  /// 1. Unlock and log out an existing session when necessary.
  /// 2. Empty credentials click validation
  /// 3. Invalid credentials authentication failure check
  /// 4. Valid credentials submission
  /// 5. Terminal selection continue button tap
  /// 6. Home screen navigation verification
  /// 7. Post-login logout cleanup back to LoginScreen
  Future<LoginRunResult> runFullSequence(
    LoginScenario scenario, {
    required Uri vmServiceUri,
    ExecutionSpeed speed = const ExecutionSpeed(),
    Duration timeout = const Duration(seconds: 45),
    DriverEngine? driverEngine,
    void Function(ExecutionEvent event)? onExecutionEvent,
    void Function(String scenarioName)? onScenarioCompleted,
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final delay = speed.delay;

    final executed = <String>[];
    void emit(
      String title,
      String message, {
      ExecutionEventLevel level = ExecutionEventLevel.info,
    }) {
      onExecutionEvent?.call(
        ExecutionEvent(title: title, message: message, level: level),
      );
    }

    try {
      await engine.connect(vmServiceUri, timeout: timeout);
      emit('Driver Connected', 'Connected to PenguinPOS Flutter Driver.');

      await _ensureLoggedOut(engine, timeout: timeout, delay: delay);
      emit('Session Reset', 'Login screen is ready for validation.');

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
      executed.add('Login Validation');
      onScenarioCompleted?.call('Login Validation');
      emit('Login Validation', 'Empty credential validation completed.');

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
      executed.add('Auth Failure Handling');
      onScenarioCompleted?.call('Auth Failure Handling');
      emit(
        'Invalid Credentials Check',
        'Authentication failure handling completed.',
      );

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
      executed.add('Valid Login Flow');
      onScenarioCompleted?.call('Valid Login Flow');
      emit('Valid Login', 'Terminal selection completed and Home is visible.');

      bool cleanupPassed = true;
      String? cleanupDetail;
      try {
        await _ensureLoggedOut(engine, timeout: timeout, delay: delay);
        emit(
          'Logout Completed',
          'Returned to Login screen.',
          level: ExecutionEventLevel.success,
        );
      } catch (cleanupError) {
        cleanupPassed = false;
        cleanupDetail = redactSecrets(cleanupError.toString(), <String?>[
          scenario.loginId,
          scenario.password,
          scenario.unlockPin,
        ]);
        emit(
          'Cleanup Warning',
          'All login scenarios passed, but the session could not be reset. Test isolation is not guaranteed.',
          level: ExecutionEventLevel.error,
        );
      }

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
        cleanupPassed: cleanupPassed,
        cleanupDetail: cleanupDetail,
      );
    } catch (error) {
      final errorStr = redactSecrets(error.toString(), <String?>[
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ]);
      emit('Login Suite Error', errorStr, level: ExecutionEventLevel.error);
      final isAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');

      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
        error: errorStr,
        wasAppClosedByUser: isAppClosed,
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

      await _ensureLoggedOut(engine, timeout: timeout, delay: delay);

      // Step 2: Wait for login screen and enter Login ID
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

      // Step 3: Enter Password
      await engine.enterText(
        PenguinPosLoginKeys.password,
        scenario.password,
        delay: delay,
      );

      // Step 4: Submit login credentials
      await engine.tap(PenguinPosLoginKeys.submit, delay: delay);

      // Step 5: Wait for Terminal Configuration screen & tap Continue button
      await engine.waitFor(
        scenario.terminalContinueKey,
        timeout: timeout,
        delay: delay,
      );
      await engine.tap(scenario.terminalContinueKey, delay: delay);

      // Step 6: Wait until app navigates into Home Screen
      await engine.waitFor(
        scenario.expectedKey,
        timeout: timeout,
        delay: delay,
      );

      await _ensureLoggedOut(engine, timeout: timeout, delay: delay);

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: const <String>['Valid Login Flow'],
        vmServiceUri: vmServiceUri,
      );
    } catch (error) {
      final errorStr = redactSecrets(error.toString(), <String?>[
        scenario.loginId,
        scenario.password,
        scenario.unlockPin,
      ]);
      final isAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');

      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        vmServiceUri: vmServiceUri,
        error: errorStr,
        wasAppClosedByUser: isAppClosed,
      );
    } finally {
      await engine.close();
    }
  }
}
