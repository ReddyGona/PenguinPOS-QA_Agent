import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Probe interface for verifying Dart VM Service readiness via WebSocket JSON-RPC.
abstract class VmServiceProbe {
  /// Connects to `wsUri` (e.g. `ws://127.0.0.1:8888/ws`), issues `getVersion`,
  /// and returns true only if a valid VM service protocol version response is received.
  Future<bool> verifyVmService(
    Uri wsUri, {
    Duration timeout = const Duration(seconds: 3),
  });
}

/// Standard production implementation of [VmServiceProbe] using native `dart:io` [WebSocket].
class DefaultVmServiceProbe implements VmServiceProbe {
  const DefaultVmServiceProbe();

  @override
  Future<bool> verifyVmService(
    Uri wsUri, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    WebSocket? ws;
    try {
      ws = await WebSocket.connect(wsUri.toString()).timeout(timeout);
      final completer = Completer<bool>();

      final subscription = ws.listen(
        (data) {
          try {
            final decoded = jsonDecode(data.toString());
            if (decoded is Map && decoded['result'] is Map) {
              final result = decoded['result'] as Map;
              if (result['type'] == 'Version' || result.containsKey('major')) {
                if (!completer.isCompleted) completer.complete(true);
              }
            }
          } catch (_) {}
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Send standard JSON-RPC getVersion request
      ws.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': 'qa_probe_1',
          'method': 'getVersion',
          'params': <String, Object?>{},
        }),
      );

      final success = await completer.future.timeout(
        timeout,
        onTimeout: () => false,
      );
      await subscription.cancel();
      return success;
    } catch (_) {
      return false;
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
    }
  }
}
