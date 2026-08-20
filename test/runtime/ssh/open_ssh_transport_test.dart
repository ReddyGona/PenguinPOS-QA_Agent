import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/open_ssh_transport.dart';

void main() {
  group('OpenSshTransport', () {
    test(
      'constructs loopback-strict tunnel command with ExitOnForwardFailure',
      () async {
        String? capturedExecutable;
        List<String>? capturedArgs;

        final transport = OpenSshTransport(
          processStarter: (exec, args) async {
            capturedExecutable = exec;
            capturedArgs = args;
            return Process.start('sh', const ['-c', 'sleep 10']);
          },
          defaultKnownHostsPath: '/tmp/test_known_hosts',
        );

        const config = QaSshConfig(
          host: '10.3.10.210',
          port: 22,
          username: 'savo',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
        );

        final handle = await transport.openLocalTunnel(
          config: config,
          localPort: 54321,
          remotePort: 8888,
        );

        expect(capturedExecutable, 'ssh');
        expect(capturedArgs, contains('-N'));
        expect(capturedArgs, contains('-L'));
        expect(capturedArgs, contains('127.0.0.1:54321:127.0.0.1:8888'));
        expect(capturedArgs, contains('-o'));
        expect(capturedArgs, contains('ExitOnForwardFailure=yes'));
        expect(capturedArgs, contains('savo@10.3.10.210'));

        await handle.close();
      },
    );

    test(
      'resolveSshOptions includes custom known_hosts and strict key checking',
      () {
        final transport = OpenSshTransport(
          defaultKnownHostsPath: '/tmp/default_known_hosts',
        );

        const config = QaSshConfig(
          host: '10.3.10.210',
          port: 2222,
          username: 'savo',
          privateKeyPath: '/tmp/id_test',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
          knownHostsPath: '/tmp/custom_known_hosts',
          strictHostKeyChecking: true,
        );

        final opts = transport.resolveSshOptions(config);
        expect(opts, contains('-p'));
        expect(opts, contains('2222'));
        expect(opts, contains('-i'));
        expect(opts, contains('/tmp/id_test'));
        expect(opts, contains('UserKnownHostsFile=/tmp/custom_known_hosts'));
        expect(opts, contains('StrictHostKeyChecking=yes'));
        expect(opts, contains('BatchMode=yes'));
      },
    );
  });
}
