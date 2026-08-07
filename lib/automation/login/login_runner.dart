import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/core/execution_speed.dart';
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
    this.wasAppClosedByUser = false,
  });

  final bool passed;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String speed;
  final List<String> scenariosExecuted;
  final Uri? vmServiceUri;
  final String? error;
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
  };
}

/// Executes login & terminal configuration actions via DriverEngine against a running PenguinPOS instance.
class PenguinPosLoginRunner {
  void _trace(String message) {
    stderr.writeln('[PenguinPOS QA][login] $message');
  }

  /// Ensures the app is at Login before starting a suite.
  ///
  /// Startup is synchronized through the target widget tree: Login, Idle Lock,
  /// or Home. An existing locked session must be unlocked before the Logout
  /// action is available.
  Future<void> _ensureLoggedOut(
    DriverEngine engine, {
    required String? unlockPin,
    Duration timeout = const Duration(seconds: 45),
    Duration delay = Duration.zero,
  }) async {
    final initialState = await engine.waitForAnyKey(<String>[
      PenguinPosLoginKeys.idleWidget,
      PenguinPosLoginKeys.loginId,
      PenguinPosLoginKeys.homeScreen,
    ], timeout: timeout);
    _trace('Initial UI state: $initialState');

    if (initialState == PenguinPosLoginKeys.loginId) {
      _trace('App is already on Login; no session reset is needed.');
      return;
    }

    if (initialState == PenguinPosLoginKeys.idleWidget) {
      if (unlockPin == null || unlockPin.trim().isEmpty) {
        throw StateError(
          'PenguinPOS is locked. Supply the terminal unlock PIN to continue.',
        );
      }
      if (!RegExp(r'^\d{4}$').hasMatch(unlockPin)) {
        throw ArgumentError.value(
          unlockPin,
          'unlockPin',
          'must contain exactly four digits.',
        );
      }

      await engine.waitFor(PenguinPosLoginKeys.idlePinInput, timeout: timeout);
      _trace(
        'Idle lock detected; entering a ${unlockPin.length}-digit PIN with the custom numpad.',
      );
      for (var index = 0; index < unlockPin.length; index++) {
        final key = PenguinPosLoginKeys.idleNumpadDigit(unlockPin[index]);
        await engine.waitFor(key, timeout: timeout);
        await engine.tap(key, delay: delay);
        _trace('Tapped idle numpad digit ${index + 1}/${unlockPin.length}.');
      }
      await engine.tap(PenguinPosLoginKeys.idleUnlock, delay: delay);
      _trace('Tapped Unlock; waiting for the idle lock widget to disappear.');

      // Passcode validation is an API call. Wait for the lock to be removed,
      // then for Home's logout control instead of guessing a completion time.
      await engine.waitForAbsent(
        PenguinPosLoginKeys.idleWidget,
        timeout: timeout,
      );
      _trace('Idle lock closed successfully.');
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
      await engine.waitForText('LOGOUT', timeout: timeout);
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
  }) async {
    final startedAt = DateTime.now();
    final engine = driverEngine ?? DriverEngine();
    final delay = speed.delay;
    final executed = <String>[];

    try {
      await engine.connect(vmServiceUri, timeout: timeout);

      await _ensureLoggedOut(
        engine,
        unlockPin: scenario.unlockPin,
        timeout: timeout,
        delay: delay,
      );

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

      await _ensureLoggedOut(
        engine,
        unlockPin: scenario.unlockPin,
        timeout: timeout,
        delay: delay,
      );

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
      );
    } catch (error) {
      final errorStr = error.toString();
      final isAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');

      // Attempt to query live route and dialog diagnostics from target app
      final diag = await engine.getDiagnostics();
      final diagSuffix = diag != null
          ? '\n\n🔍 Target App Diagnostics:\n• Active Route: ${diag.currentRoute}\n• Open Dialog: ${diag.isDialogOpen}\n• Bottom Sheet: ${diag.isBottomSheetOpen}'
          : '';

      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: executed,
        vmServiceUri: vmServiceUri,
        error: '$errorStr$diagSuffix',
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

      await _ensureLoggedOut(
        engine,
        unlockPin: scenario.unlockPin,
        timeout: timeout,
        delay: delay,
      );

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

      await _ensureLoggedOut(
        engine,
        unlockPin: scenario.unlockPin,
        timeout: timeout,
        delay: delay,
      );

      return LoginRunResult(
        passed: true,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        scenariosExecuted: const <String>['Valid Login Flow'],
        vmServiceUri: vmServiceUri,
      );
    } catch (error) {
      final errorStr = error.toString();
      final isAppClosed =
          errorStr.contains('Service has disappeared') ||
          errorStr.contains('112') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('Closed') ||
          errorStr.contains('exited');

      final diag = await engine.getDiagnostics();
      final diagSuffix = diag != null
          ? '\n\n🔍 Target App Diagnostics:\n• Active Route: ${diag.currentRoute}\n• Open Dialog: ${diag.isDialogOpen}\n• Bottom Sheet: ${diag.isBottomSheetOpen}'
          : '';

      return LoginRunResult(
        passed: false,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        speed: speed.name,
        vmServiceUri: vmServiceUri,
        error: '$errorStr$diagSuffix',
        wasAppClosedByUser: isAppClosed,
      );
    } finally {
      await engine.close();
    }
  }
}
