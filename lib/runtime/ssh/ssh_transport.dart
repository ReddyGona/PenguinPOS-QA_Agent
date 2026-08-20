import 'dart:async';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';

/// Result of probing SSH target connection.
class SshProbeResult {
  const SshProbeResult({
    required this.success,
    this.errorMessage,
    this.hostFingerprint,
    this.remoteEnvironment = const <String, String>{},
    this.binaryExists = false,
    this.binaryArchitecture,
    this.deviceArchitecture,
  });

  final bool success;
  final String? errorMessage;
  final String? hostFingerprint;
  final Map<String, String> remoteEnvironment;
  final bool binaryExists;
  final String? binaryArchitecture;
  final String? deviceArchitecture;
}

/// Result of executing a remote command over SSH.
class SshCommandResult {
  const SshCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Abstract lifecycle handle for an established SSH local port-forwarding tunnel.
abstract class SshTunnelHandle {
  /// The local loopback port bound on the host machine (127.0.0.1).
  int get localPort;

  /// Completes when the underlying tunnel process exits.
  Future<int> get exitCode;

  /// Closes and cleans up the local tunnel.
  Future<void> close();
}

/// Abstract contract for SSH operations: remote execution, probe, and tunnels.
abstract class SshTransport {
  /// Probes remote connectivity, checks remote app root, and optionally queries host fingerprint.
  Future<SshProbeResult> testConnection(QaSshConfig config);

  /// Executes a single command on the remote host.
  Future<SshCommandResult> runCommand(
    QaSshConfig config,
    String command, {
    Duration? timeout,
  });

  /// Establishes an SSH local port-forwarding tunnel binding strictly to loopback:
  /// `-L 127.0.0.1:<localPort>:127.0.0.1:<remotePort>`.
  Future<SshTunnelHandle> openLocalTunnel({
    required QaSshConfig config,
    required int localPort,
    required int remotePort,
  });

  /// Fetches the SHA-256 host key fingerprint from the target server.
  Future<String?> fetchHostFingerprint(String host, {int port = 22});

  /// Trusts the specified host key and records it in the dedicated known_hosts file.
  Future<void> trustHostKey({
    required String host,
    required int port,
    required String knownHostsPath,
  });
}
