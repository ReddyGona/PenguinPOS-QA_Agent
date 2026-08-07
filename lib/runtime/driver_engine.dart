import 'dart:async';
import 'dart:convert';
import 'package:flutter_driver/flutter_driver.dart';

/// Diagnostics snapshot from target Flutter application.
class DriverDiagnostics {
  const DriverDiagnostics({
    required this.currentRoute,
    required this.isDialogOpen,
    required this.isBottomSheetOpen,
    this.rawResponse,
  });

  final String currentRoute;
  final bool isDialogOpen;
  final bool isBottomSheetOpen;
  final String? rawResponse;

  @override
  String toString() =>
      'Route: $currentRoute · Dialog: ${isDialogOpen ? "Open" : "Closed"}';
}

/// Reusable wrapper for FlutterDriver connection, key, and text finder UI interactions.
class DriverEngine {
  FlutterDriver? _driver;

  Future<FlutterDriver> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    _driver = await FlutterDriver.connect(
      dartVmServiceUrl: vmServiceUri.toString(),
      timeout: timeout,
    );
    return _driver!;
  }

  /// Requests live route, screen, and dialog diagnostics from PenguinPOS app.
  Future<DriverDiagnostics?> getDiagnostics() async {
    final driver = _driver;
    if (driver == null) return null;
    try {
      final raw = await driver.requestData('get_diagnostics');
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, Object?>;
        return DriverDiagnostics(
          currentRoute: (decoded['currentRoute'] as String?) ?? 'unknown',
          isDialogOpen: (decoded['isDialogOpen'] as bool?) ?? false,
          isBottomSheetOpen: (decoded['isBottomSheetOpen'] as bool?) ?? false,
          rawResponse: raw,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitFor(find.byValueKey(key), timeout: timeout);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  /// Waits for a keyed widget to be removed from the widget tree.
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
    Duration? delay,
  }) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.waitForAbsent(find.byValueKey(key), timeout: timeout);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  /// Waits until one of [keys] appears and returns the matching key.
  ///
  /// Flutter Driver cannot wait for an OR finder, so this performs short,
  /// bounded probes. The target application's widget state, rather than a
  /// fixed startup delay, determines when the caller proceeds.
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
    while (DateTime.now().isBefore(deadline)) {
      for (final key in candidates) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final keyFound = await hasKey(
          key,
          timeout: remaining < probeTimeout ? remaining : probeTimeout,
        );
        if (keyFound) return key;
      }
    }

    throw TimeoutException(
      'Timed out waiting for one of: ${candidates.join(', ')}.',
      timeout,
    );
  }

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

  Future<void> enterText(String key, String text, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.byValueKey(key));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    await driver.enterText(text);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  Future<void> enterTextDirect(String text, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.enterText(text);
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  Future<void> tap(String key, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.byValueKey(key));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  Future<void> tapText(String text, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.text(text));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

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

  Future<void> stepPause(Duration delay) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  Future<void> close() async {
    await _driver?.close();
    _driver = null;
  }
}
