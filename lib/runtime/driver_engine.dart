import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/pos_automation_contract.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';

void _log(String message) {
  developer.log(message, name: 'DriverEngine');
}

/// Pure Dart WebSocket client for the Flutter Driver VM Service extension.
///
/// Communicates directly via the `ext.flutter.driver` JSON-RPC protocol over
/// `dart:io` WebSocket, eliminating any dependency on `dart:ui` or the Flutter SDK
/// runtime on the host machine.
class DriverEngine implements Driver {
  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSubscription;
  int _nextId = 1;
  final Map<String, Completer<Map<String, Object?>>> _pendingRequests =
      <String, Completer<Map<String, Object?>>>{};
  Timer? _qaNoticeDismissTimer;

  bool get isConnected => _ws != null;

  String? _mainIsolateId;

  @override
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await close();

    final wsUri = _normalizeWsUri(vmServiceUri);
    _log('Connecting to VM Service WebSocket: $wsUri');

    final ws = await WebSocket.connect(wsUri.toString()).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Timed out connecting to VM Service at $wsUri',
        timeout,
      ),
    );

    _ws = ws;
    _wsSubscription = ws.listen(
      _handleIncomingMessage,
      onError: (Object error) {
        _log('WebSocket error: $error');
        _failPendingRequests('WebSocket error: $error');
      },
      onDone: () {
        _log('WebSocket connection closed');
        _failPendingRequests('WebSocket connection closed');
      },
    );

    // Discover UI isolate from target VM Service
    try {
      final vmResponse = await _sendRpc(
        'getVM',
        <String, Object?>{},
        timeout: const Duration(seconds: 10),
      );
      final isolates = vmResponse['isolates'];
      if (isolates is List && isolates.isNotEmpty) {
        final firstIsolate = isolates.first;
        if (firstIsolate is Map) {
          _mainIsolateId = firstIsolate['id']?.toString();
          _log('Discovered main isolate ID: $_mainIsolateId');
        }
      }
    } catch (e) {
      _log('Warning: Unable to query getVM for isolate ID: $e');
    }
  }

  Uri _normalizeWsUri(Uri uri) {
    var scheme = uri.scheme;
    if (scheme == 'http') scheme = 'ws';
    if (scheme == 'https') scheme = 'wss';
    if (scheme.isEmpty) scheme = 'ws';

    var path = uri.path;
    if (!path.endsWith('/ws')) {
      if (path.endsWith('/')) {
        path = '${path}ws';
      } else {
        path = '$path/ws';
      }
    }
    return uri.replace(scheme: scheme, path: path);
  }

  void _handleIncomingMessage(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final map = Map<String, Object?>.from(decoded);
      final id = map['id']?.toString();
      if (id != null && _pendingRequests.containsKey(id)) {
        _pendingRequests.remove(id)?.complete(map);
      }
    } catch (e) {
      _log('Failed to parse incoming WebSocket message: $e');
    }
  }

  void _failPendingRequests(String reason) {
    final pending = Map<String, Completer<Map<String, Object?>>>.from(
      _pendingRequests,
    );
    _pendingRequests.clear();
    for (final completer in pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(reason));
      }
    }
  }

  Future<Map<String, Object?>> _sendRpc(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final ws = _ws;
    if (ws == null) {
      throw StateError('Driver is not connected to target VM Service');
    }

    final id = (_nextId++).toString();
    final completer = Completer<Map<String, Object?>>();
    _pendingRequests[id] = completer;

    final requestPayload = jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    ws.add(requestPayload);

    try {
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(id);
          throw TimeoutException(
            'Timed out waiting for RPC response ($method)',
            timeout,
          );
        },
      );

      if (response.containsKey('error')) {
        final err = response['error'];
        throw StateError('Driver RPC error: $err');
      }

      final result = response['result'];
      if (result is Map) {
        final resultMap = Map<String, Object?>.from(result);
        final responseData = resultMap['response'];
        if (responseData is Map) {
          final resMap = Map<String, Object?>.from(responseData);
          if (resMap['isError'] == true) {
            throw StateError(
              'FlutterDriver command error: ${resMap['response'] ?? resMap['message']}',
            );
          }
        }
        return resultMap;
      }
      return <String, Object?>{};
    } catch (e) {
      _pendingRequests.remove(id);
      rethrow;
    }
  }

  Future<Map<String, Object?>> _sendDriverCommand(
    String command,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _sendRpc('ext.flutter.driver', <String, Object?>{
      if (_mainIsolateId != null) 'isolateId': _mainIsolateId,
      'command': command,
      'timeout': timeout.inMilliseconds.toString(),
      ...params,
    }, timeout: timeout);
  }

  @override
  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 500);
    var probeCount = 0;

    _log('[DriverEngine] waitFor("$key") started, timeout=$timeout');
    while (_ws != null && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      probeCount++;
      final found = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (found) {
        _log('[DriverEngine] waitFor("$key") FOUND after $probeCount probes');
        return;
      }
    }

    _log('[DriverEngine] waitFor("$key") TIMEOUT after $probeCount probes');
    throw TimeoutException('Timed out waiting for key "$key".', timeout);
  }

  @override
  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    const probeTimeout = Duration(milliseconds: 250);

    _log('[DriverEngine] waitForAbsent("$key") started, timeout=$timeout');
    while (_ws != null && DateTime.now().isBefore(deadline)) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      final exists = await hasKey(
        key,
        timeout: remaining < probeTimeout ? remaining : probeTimeout,
      );
      if (!exists) {
        _log('[DriverEngine] waitForAbsent("$key") CLEARED (widget absent)');
        return;
      }
    }

    _log('[DriverEngine] waitForAbsent("$key") TIMEOUT');
    throw TimeoutException(
      'Timed out waiting for key "$key" to disappear.',
      timeout,
    );
  }

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

    _log(
      '[DriverEngine] waitForAnyKey(${candidates.join(", ")}) started, timeout=$timeout',
    );
    while (_ws != null && DateTime.now().isBefore(deadline)) {
      cycleCount++;
      for (final key in candidates) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final keyFound = await hasKey(
          key,
          timeout: remaining < probeTimeout ? remaining : probeTimeout,
        );
        if (keyFound) {
          _log(
            '[DriverEngine] waitForAnyKey FOUND "$key" on cycle #$cycleCount',
          );
          return key;
        }
      }
    }

    _log(
      '[DriverEngine] waitForAnyKey TIMEOUT after $cycleCount cycles. Keys: ${candidates.join(", ")}',
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
  }) async {
    await _sendDriverCommand('waitFor', <String, Object?>{
      'finderType': 'ByText',
      'text': text,
    }, timeout: timeout);
  }

  @override
  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_ws == null) return false;
    try {
      await _sendDriverCommand('waitFor', <String, Object?>{
        'finderType': 'ByValueKey',
        'keyValueString': key,
        'keyValueType': 'String',
      }, timeout: timeout);
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
    if (_ws == null) return false;
    try {
      await _sendDriverCommand('waitFor', <String, Object?>{
        'finderType': 'ByText',
        'text': text,
      }, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    _log('[DriverEngine] enterText("$key", ${text.length} chars)');
    await tap(key);
    await _sendDriverCommand('enter_text', <String, Object?>{
      'text': text,
    }, timeout: timeout);
  }

  @override
  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.driverDirect,
  }) async {
    if (mode == TextInputMode.driverDirect) {
      await enterText(targetInputKey, text);
      return;
    }

    await tap(targetInputKey);
    await _sendDriverCommand('enter_text', <String, Object?>{'text': ''});

    var isShiftActive = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (mode == TextInputMode.customQwertyPad) {
        if (!RegExp(r'^[a-zA-Z0-9.,_/# ]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason:
                'CustomQwertyPad layout cannot represent character at index',
          );
        }

        final isUpper = RegExp(r'^[A-Z]$').hasMatch(char);

        if (isUpper && !isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix));
          isShiftActive = true;
        } else if (!isUpper && isShiftActive) {
          await tap(PosAutomationContract.qwertyShift(keyPrefix));
          isShiftActive = false;
        }

        if (char == ' ') {
          await tap(PosAutomationContract.qwertySpace(keyPrefix));
        } else {
          await tap(
            PosAutomationContract.qwertyKey(keyPrefix, char.toLowerCase()),
          );
        }
      } else if (mode == TextInputMode.customNumPad) {
        if (!RegExp(r'^[0-9.]$').hasMatch(char)) {
          throw UnsupportedKeyboardCharacterException(
            position: i + 1,
            reason: 'CustomNumPad layout cannot represent character at index',
          );
        }
        await tap(PosAutomationContract.numpadDigit(keyPrefix, char));
      }
    }

    if (isShiftActive) {
      await tap(PosAutomationContract.qwertyShift(keyPrefix));
    }
  }

  @override
  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_ws == null) return null;
    try {
      return await getText(key, timeout: timeout);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final result = await _sendDriverCommand('get_text', <String, Object?>{
      'finderType': 'ByValueKey',
      'keyValueString': key,
      'keyValueType': 'String',
    }, timeout: timeout);

    final response = result['response'];
    if (response is Map) {
      final text = response['text'] ?? response['response'];
      return text?.toString() ?? '';
    }
    return '';
  }

  @override
  Future<void> tap(String key) async {
    await _sendDriverCommand('tap', <String, Object?>{
      'finderType': 'ByValueKey',
      'keyValueString': key,
      'keyValueType': 'String',
    });
  }

  @override
  Future<void> tapText(String text) async {
    await _sendDriverCommand('tap', <String, Object?>{
      'finderType': 'ByText',
      'text': text,
    });
  }

  @override
  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_ws == null) return false;
    try {
      await tapText(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_ws == null) return false;
    try {
      await tap(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_ws == null) return null;
    final start = DateTime.now();
    try {
      final result = await _sendDriverCommand('request_data', <String, Object?>{
        'message': message,
      }, timeout: timeout);
      final durationMs = DateTime.now().difference(start).inMilliseconds;
      _log('[DriverEngine] requestData completed in ${durationMs}ms');
      final response = result['response'];
      if (response is Map) {
        final msg = response['message'] ?? response['response'];
        return msg?.toString();
      }
      return null;
    } catch (_) {
      final durationMs = DateTime.now().difference(start).inMilliseconds;
      _log('[DriverEngine] requestData failed after ${durationMs}ms');
      return null;
    }
  }

  @override
  Future<bool> clearSnackBars() async {
    final res = await requestData('clear_snackbars');
    final isAcknowledged = res == 'cleared' || res == 'snackbars_cleared';
    if (!isAcknowledged) {
      _log(
        '[DriverEngine] clearSnackBars unacknowledged or extension unsupported (status="${res == null
            ? 'null'
            : res.contains('No requestData')
            ? 'unsupported'
            : 'unrecognized'}")',
      );
    }
    return isAcknowledged;
  }

  @override
  Future<bool> showQaTestNotice(QaTestNotice notice) async {
    _qaNoticeDismissTimer?.cancel();
    final response = await requestData(
      jsonEncode(notice.toJson()),
      timeout: const Duration(milliseconds: 700),
    );
    final acknowledged = response == 'shown' || response == 'notice_shown';
    if (acknowledged) {
      _qaNoticeDismissTimer = Timer(const Duration(milliseconds: 700), () {
        unawaited(clearQaTestNotice());
      });
    }
    if (!acknowledged) {
      _log('[DriverEngine] QA notice unacknowledged or extension unsupported');
    }
    return acknowledged;
  }

  @override
  Future<bool> clearQaTestNotice() async {
    _qaNoticeDismissTimer?.cancel();
    _qaNoticeDismissTimer = null;
    final response = await requestData(
      'qa_notice_clear',
      timeout: const Duration(milliseconds: 700),
    );
    final acknowledged = response == 'cleared' || response == 'notice_cleared';
    if (!acknowledged) {
      _log(
        '[DriverEngine] QA notice clear unacknowledged or extension unsupported',
      );
    }
    return acknowledged;
  }

  @override
  Future<void> close() async {
    _qaNoticeDismissTimer?.cancel();
    _qaNoticeDismissTimer = null;
    _failPendingRequests('Driver closed');
    final sub = _wsSubscription;
    _wsSubscription = null;
    await sub?.cancel();
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (_) {}
  }
}
