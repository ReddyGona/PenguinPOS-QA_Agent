import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_transport.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/vm_service_probe.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh_app_launcher.dart';

class _MockSshTransport implements SshTransport {
  bool failNextProbe = false;
  String lastRunCommand = '';
  int openTunnelCalls = 0;

  @override
  Future<SshProbeResult> testConnection(QaSshConfig config) async {
    if (failNextProbe) {
      return const SshProbeResult(
        success: false,
        errorMessage: 'Host unreachable',
      );
    }
    return const SshProbeResult(
      success: true,
      binaryExists: true,
      deviceArchitecture: 'x86_64',
    );
  }

  @override
  Future<SshCommandResult> runCommand(
    QaSshConfig config,
    String command, {
    Duration? timeout,
  }) async {
    lastRunCommand = command;
    if (command.contains('uname -m')) {
      return const SshCommandResult(
        exitCode: 0,
        stdout: 'ARCH:x86_64|ELF 64-bit LSB pie executable, x86-64',
        stderr: '',
      );
    }
    if (command.contains('setsid')) {
      return const SshCommandResult(
        exitCode: 0,
        stdout: '12345:987654321',
        stderr: '',
      );
    }
    return const SshCommandResult(exitCode: 0, stdout: 'OK', stderr: '');
  }

  @override
  Future<SshTunnelHandle> openLocalTunnel({
    required QaSshConfig config,
    required int localPort,
    required int remotePort,
  }) async {
    openTunnelCalls++;
    return _MockTunnelHandle(localPort);
  }

  @override
  Future<String?> fetchHostFingerprint(String host, {int port = 22}) async =>
      'SHA256:abc123test';

  @override
  Future<void> trustHostKey({
    required String host,
    required int port,
    required String knownHostsPath,
  }) async {}
}

class _MockTunnelHandle implements SshTunnelHandle {
  _MockTunnelHandle(this.localPort);

  @override
  final int localPort;

  @override
  Future<int> get exitCode async => -999;

  @override
  Future<void> close() async {}
}

class _MockVmServiceProbe implements VmServiceProbe {
  int callCount = 0;
  bool returnReady = true;

  @override
  Future<bool> verifyVmService(
    Uri wsUri, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    callCount++;
    return returnReady;
  }
}

void main() {
  group('SshAppLauncher with mock transport and probe', () {
    test('shellQuote safely escapes strings for POSIX shell', () {
      expect(SshAppLauncher.shellQuote(''), "''");
      expect(SshAppLauncher.shellQuote('hello'), "'hello'");
      expect(
        SshAppLauncher.shellQuote("/home/savo/Documents/penguin_pos"),
        "'/home/savo/Documents/penguin_pos'",
      );
      expect(SshAppLauncher.shellQuote("it's a test"), "'it'\\''s a test'");
    });

    test('preflights ELF architecture matching x86_64 target', () async {
      final mockTransport = _MockSshTransport();
      final launcher = SshAppLauncher(transport: mockTransport);

      const config = QaSshConfig(
        host: '10.3.10.210',
        username: 'savo',
        remoteAppRoot: '/home/savo/Documents/penguin_pos',
        launchMethod: SshLaunchMethod.prebuiltBinary,
      );

      final error = await launcher.preflightPrebuiltBinary(config);
      expect(error, isNull);
      expect(mockTransport.lastRunCommand, contains('uname -m'));
    });

    test(
      'launches remote process and establishes loopback-verified tunnel',
      () async {
        final mockTransport = _MockSshTransport();
        final mockProbe = _MockVmServiceProbe();
        final launcher = SshAppLauncher(
          transport: mockTransport,
          vmProbe: mockProbe,
        );

        const config = QaSshConfig(
          host: '10.3.10.210',
          username: 'savo',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
        );

        final handle = await launcher.launch(
          config: config,
          entity: 'kpn',
          env: 'dev',
        );

        expect(handle.remotePid, 12345);
        expect(handle.remoteStartTime, '987654321');
        expect(handle.vmServiceUri.scheme, 'ws');
        expect(handle.vmServiceUri.host, '127.0.0.1');
        expect(mockProbe.callCount, greaterThanOrEqualTo(1));
        expect(mockTransport.lastRunCommand, contains('</dev/null'));
        expect(
          mockTransport.lastRunCommand,
          contains('--dart-define=ENABLE_FLUTTER_DRIVER=true'),
        );
        expect(
          mockTransport.lastRunCommand,
          contains("--dart-define=ENTITY='kpn'"),
        );
        expect(mockTransport.lastRunCommand, contains('setsid --fork'));
        expect(mockTransport.lastRunCommand, contains('PID_FILE='));
        expect(mockTransport.lastRunCommand, contains('cat "\$PID_FILE"'));

        // Teardown
        await handle.close();
        expect(mockTransport.lastRunCommand, contains('kill -TERM -- -12345'));
      },
    );
  });
}
