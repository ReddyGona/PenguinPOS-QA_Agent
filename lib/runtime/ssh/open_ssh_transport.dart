import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_transport.dart';

/// Function signature for running external processes. Enables full unit test mocking.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      Duration? timeout,
    });

/// Function signature for starting long-running background processes.
typedef ProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

/// OpenSSH implementation of [SshTunnelHandle].
class OpenSshTunnelHandle implements SshTunnelHandle {
  OpenSshTunnelHandle({required this.localPort, required this.process}) {
    _exitCodeCompleter = Completer<int>();
    process.exitCode.then((code) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(code);
      }
    });
  }

  @override
  final int localPort;
  final Process process;
  late final Completer<int> _exitCodeCompleter;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  Future<void> close() async {
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {}
          return -1;
        },
      );
    } catch (_) {}
  }
}

/// Production implementation of [SshTransport] using system OpenSSH.
class OpenSshTransport implements SshTransport {
  OpenSshTransport({
    ProcessRunner? processRunner,
    ProcessStarter? processStarter,
    String? defaultKnownHostsPath,
  }) : _runner = processRunner ?? _defaultProcessRunner,
       _starter = processStarter ?? _defaultProcessStarter,
       _defaultKnownHostsPath =
           defaultKnownHostsPath ?? _resolveDefaultKnownHostsPath();

  final ProcessRunner _runner;
  final ProcessStarter _starter;
  final String _defaultKnownHostsPath;

  static String _resolveDefaultKnownHostsPath() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return '.known_hosts';
    final dir = Directory('$home/.penguin_pos_qa');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return '${dir.path}/known_hosts';
  }

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async {
    final future = Process.run(executable, arguments);
    if (timeout != null) {
      return future.timeout(timeout);
    }
    return future;
  }

  static Future<Process> _defaultProcessStarter(
    String executable,
    List<String> arguments,
  ) => Process.start(executable, arguments);

  /// Resolves SSH options including auto-discovered keys in ~/.ssh.
  List<String> resolveSshOptions(QaSshConfig config) {
    final knownHosts = config.knownHostsPath ?? _defaultKnownHostsPath;
    final args = <String>[
      '-p',
      '${config.port}',
      '-o',
      'ConnectTimeout=5',
      '-o',
      'BatchMode=yes',
      '-o',
      'UserKnownHostsFile=$knownHosts',
      '-o',
      config.strictHostKeyChecking
          ? 'StrictHostKeyChecking=yes'
          : 'StrictHostKeyChecking=accept-new',
    ];

    if (config.privateKeyPath != null &&
        config.privateKeyPath!.trim().isNotEmpty) {
      args.addAll(<String>['-i', config.privateKeyPath!.trim()]);
    } else {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        for (final candidate in <String>[
          '$home/.ssh/id_work',
          '$home/.ssh/id_rsa',
          '$home/.ssh/id_ed25519',
          '$home/.ssh/id_personal',
          '$home/.ssh/id_ecdsa',
        ]) {
          if (File(candidate).existsSync()) {
            args.addAll(<String>['-i', candidate]);
          }
        }
      }
    }
    return args;
  }

  @override
  Future<SshProbeResult> testConnection(QaSshConfig config) async {
    try {
      final probeScript = [
        'test -d ${shellQuote(config.remoteAppRoot)} && echo APP_ROOT_OK',
        'test -x ${shellQuote("${config.remoteAppRoot}/${config.prebuiltBinaryPath}")} && echo BINARY_OK',
        'uname -m',
      ].join(' ; ');

      final result = await _runner('ssh', <String>[
        ...resolveSshOptions(config),
        '--',
        config.destination,
        probeScript,
      ], timeout: const Duration(seconds: 10));

      if (result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        return SshProbeResult(
          success: false,
          errorMessage: err.isNotEmpty
              ? err
              : 'SSH connection failed with exit code ${result.exitCode}.',
        );
      }

      final out = result.stdout.toString();
      final hasAppRoot = out.contains('APP_ROOT_OK');
      final hasBinary = out.contains('BINARY_OK');
      final lines = out.split('\n').map((l) => l.trim()).toList();
      final deviceArch = lines.isNotEmpty ? lines.last : 'unknown';

      if (!hasAppRoot) {
        return SshProbeResult(
          success: false,
          errorMessage:
              'Remote app directory not found: ${config.remoteAppRoot}',
        );
      }

      return SshProbeResult(
        success: true,
        binaryExists: hasBinary,
        deviceArchitecture: deviceArch,
      );
    } on TimeoutException {
      return const SshProbeResult(
        success: false,
        errorMessage: 'SSH connection timed out after 10 seconds.',
      );
    } catch (e) {
      return SshProbeResult(
        success: false,
        errorMessage: 'SSH probe error: $e',
      );
    }
  }

  @override
  Future<SshCommandResult> runCommand(
    QaSshConfig config,
    String command, {
    Duration? timeout,
  }) async {
    final result = await _runner('ssh', <String>[
      ...resolveSshOptions(config),
      '--',
      config.destination,
      command,
    ], timeout: timeout);

    return SshCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  @override
  Future<SshTunnelHandle> openLocalTunnel({
    required QaSshConfig config,
    required int localPort,
    required int remotePort,
  }) async {
    final tunnelProcess = await _starter('ssh', <String>[
      '-N',
      '-L',
      '127.0.0.1:$localPort:127.0.0.1:$remotePort',
      '-o',
      'ExitOnForwardFailure=yes',
      ...resolveSshOptions(config),
      '--',
      config.destination,
    ]);

    return OpenSshTunnelHandle(localPort: localPort, process: tunnelProcess);
  }

  @override
  Future<String?> fetchHostFingerprint(String host, {int port = 22}) async {
    try {
      final result = await _runner('ssh-keyscan', <String>[
        '-p',
        '$port',
        host,
      ], timeout: const Duration(seconds: 5));

      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final keyLine = result.stdout.toString().trim();
        // Compute SHA-256 fingerprint via ssh-keygen
        final keygenResult = await _runner('ssh-keygen', <String>[
          '-lf',
          '-',
        ], timeout: const Duration(seconds: 5));
        if (keygenResult.exitCode == 0) {
          return keygenResult.stdout.toString().trim();
        }
        return keyLine;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> trustHostKey({
    required String host,
    required int port,
    required String knownHostsPath,
  }) async {
    try {
      final scanResult = await _runner('ssh-keyscan', <String>[
        '-p',
        '$port',
        host,
      ], timeout: const Duration(seconds: 5));

      if (scanResult.exitCode == 0) {
        final keyContent = scanResult.stdout.toString().trim();
        if (keyContent.isNotEmpty) {
          final file = File(knownHostsPath);
          await file.writeAsString('$keyContent\n', mode: FileMode.append);
        }
      }
    } catch (_) {}
  }

  /// POSIX shell single quoting helper.
  static String shellQuote(String value) {
    if (value.isEmpty) return "''";
    return "'${value.replaceAll("'", "'\\''")}'";
  }
}
