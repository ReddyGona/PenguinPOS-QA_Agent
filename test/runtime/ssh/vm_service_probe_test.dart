import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/vm_service_probe.dart';

void main() {
  group('DefaultVmServiceProbe', () {
    test('verifies VM service when response contains Version result', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.transform(WebSocketTransformer()).listen((WebSocket ws) {
        ws.listen((data) {
          // Respond with valid JSON-RPC getVersion payload
          ws.add(
            '{"jsonrpc":"2.0","result":{"type":"Version","major":3,"minor":44},"id":"qa_probe_1"}',
          );
        });
      });

      const probe = DefaultVmServiceProbe();
      final isReady = await probe.verifyVmService(
        Uri.parse('ws://127.0.0.1:${server.port}/ws'),
        timeout: const Duration(seconds: 2),
      );

      expect(isReady, isTrue);
      await server.close(force: true);
    });

    test('returns false when server does not respond or times out', () async {
      const probe = DefaultVmServiceProbe();
      final isReady = await probe.verifyVmService(
        Uri.parse('ws://127.0.0.1:59999/ws'),
        timeout: const Duration(milliseconds: 200),
      );

      expect(isReady, isFalse);
    });
  });
}
