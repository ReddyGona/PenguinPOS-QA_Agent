import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';

void main() {
  group('QaSshConfig', () {
    test(
      'constructs with defaults and computes destination and sshOptionsArgs',
      () {
        const config = QaSshConfig(
          host: '10.3.10.210',
          username: 'savo',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
        );

        expect(config.destination, 'savo@10.3.10.210');
        expect(config.port, 22);
        expect(config.vmServicePort, 8888);
        expect(config.remoteDisplay, ':0');
        expect(config.remoteFlutterExecutable, 'flutter');
        expect(config.launchMethod, SshLaunchMethod.flutterRun);
        expect(config.sshOptionsArgs, <String>[
          '-p',
          '22',
          '-o',
          'StrictHostKeyChecking=yes',
          '-o',
          'BatchMode=yes',
        ]);
        expect(config.validate(), isEmpty);
      },
    );

    test(
      'includes privateKeyPath and knownHostsPath in sshOptionsArgs when specified',
      () {
        const config = QaSshConfig(
          host: '10.3.10.210',
          port: 2222,
          username: 'savo',
          privateKeyPath: '/Users/test/.ssh/id_rsa',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
          knownHostsPath: '/tmp/custom_known_hosts',
          launchMethod: SshLaunchMethod.prebuiltBinary,
        );

        expect(config.sshOptionsArgs, <String>[
          '-p',
          '2222',
          '-i',
          '/Users/test/.ssh/id_rsa',
          '-o',
          'UserKnownHostsFile=/tmp/custom_known_hosts',
          '-o',
          'StrictHostKeyChecking=yes',
          '-o',
          'BatchMode=yes',
        ]);
        expect(config.launchMethod, SshLaunchMethod.prebuiltBinary);
        expect(config.validate(), isEmpty);
      },
    );

    test('validate catches invalid fields', () {
      const config = QaSshConfig(
        host: '',
        port: 0,
        username: '',
        remoteAppRoot: '',
        vmServicePort: 80,
      );

      final issues = config.validate();
      expect(issues, contains('SSH host is required.'));
      expect(issues, contains('SSH username is required.'));
      expect(issues, contains('SSH port must be 1-65535.'));
      expect(issues, contains('Remote app root is required.'));
      expect(issues, contains('VM service port must be 1024-65535.'));
    });

    test('serializes to and from JSON', () {
      const original = QaSshConfig(
        host: '192.168.1.50',
        port: 2200,
        username: 'posadmin',
        privateKeyPath: '/path/to/key',
        remoteAppRoot: '/opt/penguin_pos',
        remoteFlutterExecutable: '/opt/flutter/bin/flutter',
        remoteDisplay: ':1',
        vmServicePort: 9000,
        launchMethod: SshLaunchMethod.prebuiltBinary,
        prebuiltBinaryPath: './custom/path/penguin_pos',
        hostFingerprint: 'SHA256:fingerprint',
      );

      final json = original.toJson();
      final reconstructed = QaSshConfig.fromJson(json);

      expect(reconstructed.host, original.host);
      expect(reconstructed.port, original.port);
      expect(reconstructed.username, original.username);
      expect(reconstructed.privateKeyPath, original.privateKeyPath);
      expect(reconstructed.remoteAppRoot, original.remoteAppRoot);
      expect(
        reconstructed.remoteFlutterExecutable,
        original.remoteFlutterExecutable,
      );
      expect(reconstructed.remoteDisplay, original.remoteDisplay);
      expect(reconstructed.vmServicePort, original.vmServicePort);
      expect(reconstructed.launchMethod, original.launchMethod);
      expect(reconstructed.prebuiltBinaryPath, original.prebuiltBinaryPath);
      expect(reconstructed.hostFingerprint, original.hostFingerprint);
    });
  });
}
