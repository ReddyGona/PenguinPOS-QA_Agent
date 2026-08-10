import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';

/// Reusable wrapper for FlutterDriver connection, key, and text finder UI interactions.
class DriverEngine implements Driver {
  FlutterDriver? _driver;

  @override
  Future<FlutterDriver> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    _driver = await FlutterDriver.connect(
      dartVmServiceUrl: vmServiceUri.toString(),
      timeout: timeout,
      // Driver command transcripts include text-entry payloads. Disable them
      // because credentials and PINs are runtime-only secrets.
      logCommunicationToFile: false,
    );
    return _driver!;
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 500);
    var probeCount = 0;

    debugPrint('[DriverEngine] waitFor("$key") started, timeout=$timeout');
    while (DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      probeCount++;
      final found = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (found) {
        debugPrint(
          '[DriverEngine] waitFor("$key") FOUND after $probeCount probes',
        );
        if (delay != null && delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        return;
      }
    }

    debugPrint(
      '[DriverEngine] waitFor("$key") TIMEOUT after $probeCount probes',
    );
    throw TimeoutException('Timed out waiting for key "$key".', timeout);
  }

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 250);

    debugPrint(
      '[DriverEngine] waitForAbsent("$key") started, timeout=$timeout',
    );
    while (DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      final exists = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (!exists) {
        debugPrint(
          '[DriverEngine] waitForAbsent("$key") CLEARED (widget absent)',
        );
        if (delay != null && delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        return;
      }
    }

    debugPrint('[DriverEngine] waitForAbsent("$key") TIMEOUT');
    throw TimeoutException(
      'Timed out waiting for key "$key" to disappear.',
      timeout,
    );
  }

  /// Waits until one of [keys] appears and returns the matching key.
  ///
  /// Flutter Driver cannot wait for an OR finder, so this performs short,
  /// bounded probes. The target application's widget state, rather than a
  /// fixed startup delay, determines when the caller proceeds.
  @override
  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final candidates = keys.toList(growable: false);
    if (candidates.isEmpty) {
      throw ArgumentError.value(keys, 'keys', 'must not be empty');
    }

    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 250);
    var cycleCount = 0;

    debugPrint(
      '[DriverEngine] waitForAnyKey(${candidates.join(", ")}) '
      'started, timeout=$timeout',
    );
    while (DateTime.now().isBefore(deadline)) {
      cycleCount++;
      for (final key in candidates) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final keyFound = await hasKey(
          key,
          timeout: remaining < probeTimeout ? remaining : probeTimeout,
        );
        if (keyFound) {
          debugPrint(
            '[DriverEngine] waitForAnyKey FOUND "$key" '
            'on cycle #$cycleCount',
          );
          return key;
        }
      }
    }

    debugPrint(
      '[DriverEngine] waitForAnyKey TIMEOUT after $cycleCount cycles. '
      'Keys: ${candidates.join(", ")}',
    );
    throw TimeoutException(
      'Timed out waiting for one of: ${candidates.join(', ')}.',
      timeout,
    );
  }

  @override
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitFor(find.text(text), timeout: timeout);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.text(text), timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration? delay,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    debugPrint('[DriverEngine] enterText("$key", ${text.length} chars)');
    await driver.tap(find.byValueKey(key), timeout: timeout);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    await driver.enterText(text, timeout: timeout);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.driverDirect,
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');

    if (mode == TextInputMode.driverDirect) {
      await enterText(targetInputKey, text, delay: delay);
      return;
    }

    // 1. Focus target input field for custom virtual keyboards
    await tap(targetInputKey, delay: delay);

    // Clear existing text field content before virtual key entry
    await driver.enterText('');

    var isShiftActive = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (mode == TextInputMode.customQwertyPad) {
        // Validate character compatibility
        if (!RegExp(r'^[a-zA-Z0-9.,_/# ]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason:
                'CustomQwertyPad layout cannot represent character at index',
          );
        }

        final isUpper = RegExp(r'^[A-Z]$').hasMatch(char);

        if (isUpper && !isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix), delay: delay);
          isShiftActive = true;
        } else if (!isUpper && isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix), delay: delay);
          isShiftActive = false;
        }

        if (char == ' ') {
          await tap(PosAutomationContract.qwertySpace(keyPrefix), delay: delay);
        } else {
          await tap(
            PosAutomationContract.qwertyKey(keyPrefix, char.toLowerCase()),
            delay: delay,
          );
        }
      } else if (mode == TextInputMode.customNumPad) {
        if (!RegExp(r'^[0-9.]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason: 'CustomNumPad layout cannot represent character at index',
          );
        }
        await tap(
          PosAutomationContract.numpadDigit(keyPrefix, char),
          delay: delay,
        );
      }
    }

    // Ensure shift state is left off
    if (isShiftActive) {
      await tap(PosAutomationContract.qwertyShift(keyPrefix), delay: delay);
    }
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final driver = _driver;
    if (driver == null) return null;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      return await driver.getText(find.byValueKey(key), timeout: timeout);
    } catch (_) {
      return null;
    }
  }

  /// Reads text from a keyed Text, RichText, or editable field.
  ///
  /// Unlike [tryGetText], this preserves driver errors so a required test
  /// value cannot silently become a default value.
  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitFor(find.byValueKey(key), timeout: timeout);
    return driver.getText(find.byValueKey(key), timeout: timeout);
  }

  Future<void> enterTextDirect(String text, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.enterText(text);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<void> tap(String key, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.byValueKey(key));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<void> tapText(String text, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.text(text));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.text(text), timeout: timeout);
      await driver.tap(find.text(text));
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) return false;
    try {
      await driver.waitFor(find.byValueKey(key), timeout: timeout);
      await driver.tap(find.byValueKey(key));
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stepPause(Duration delay) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<void> close() async {
    try {
      await _driver?.close();
    } catch (_) {}
    _driver = null;
  }
}
