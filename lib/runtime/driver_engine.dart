import 'dart:async';
import 'package:flutter_driver/flutter_driver.dart';

/// Reusable wrapper for FlutterDriver connection and UI key interactions.
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

  Future<void> tap(String key, {Duration? delay}) async {
    final driver = _driver;
    if (driver == null) throw StateError('Driver is not connected');
    await driver.tap(find.byValueKey(key));
    if (delay != null && delay > Duration.zero) {
      await Future<void>.delayed(delay);
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
