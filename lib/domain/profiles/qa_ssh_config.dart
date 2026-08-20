export 'package:penguin_pos_qa_agent/domain/profiles/qa_target_mode.dart';

enum SshLaunchMethod {
  flutterRun,
  prebuiltBinary;

  String get storageValue => switch (this) {
    SshLaunchMethod.flutterRun => 'flutter_run',
    SshLaunchMethod.prebuiltBinary => 'prebuilt_binary',
  };

  static SshLaunchMethod fromStorageValue(String? value) => switch (value) {
    'prebuilt_binary' => SshLaunchMethod.prebuiltBinary,
    _ => SshLaunchMethod.flutterRun,
  };
}

/// SSH target configuration for a remote POS device.
/// Pure domain model — decoupled from dart:io and process handles.
class QaSshConfig {
  const QaSshConfig({
    required this.host,
    this.port = 22,
    required this.username,
    this.privateKeyPath,
    required this.remoteAppRoot,
    this.remoteFlutterExecutable = 'flutter',
    this.remoteDisplay = ':0',
    this.vmServicePort = 8888,
    // `flutter run` supplies the compile-time QA driver define. A generic
    // prebuilt bundle cannot be assumed to have been compiled for automation.
    this.launchMethod = SshLaunchMethod.flutterRun,
    this.prebuiltBinaryPath = './build/linux/x64/debug/bundle/penguin_pos',
    this.hostFingerprint,
    this.knownHostsPath,
    this.strictHostKeyChecking = true,
  });

  final String host;
  final int port;
  final String username;
  final String? privateKeyPath;
  final String remoteAppRoot;
  final String remoteFlutterExecutable;
  final String remoteDisplay;
  final int vmServicePort;
  final SshLaunchMethod launchMethod;
  final String prebuiltBinaryPath;
  final String? hostFingerprint;
  final String? knownHostsPath;
  final bool strictHostKeyChecking;

  /// user@host string for SSH commands.
  String get destination => '$username@$host';

  /// SSH option arguments: [-p port] [-i keyPath] [-o BatchMode=yes]
  List<String> get sshOptionsArgs => <String>[
    '-p',
    '$port',
    if (privateKeyPath != null &&
        privateKeyPath!.trim().isNotEmpty) ...<String>[
      '-i',
      privateKeyPath!.trim(),
    ],
    if (knownHostsPath != null &&
        knownHostsPath!.trim().isNotEmpty) ...<String>[
      '-o',
      'UserKnownHostsFile=${knownHostsPath!.trim()}',
    ],
    '-o',
    strictHostKeyChecking
        ? 'StrictHostKeyChecking=yes'
        : 'StrictHostKeyChecking=accept-new',
    '-o',
    'BatchMode=yes',
  ];

  /// Returns validation issues (empty = valid).
  List<String> validate() {
    final issues = <String>[];
    if (host.trim().isEmpty) {
      issues.add('SSH host is required.');
    }
    if (username.trim().isEmpty) {
      issues.add('SSH username is required.');
    }
    if (port < 1 || port > 65535) {
      issues.add('SSH port must be 1-65535.');
    }
    if (remoteAppRoot.trim().isEmpty) {
      issues.add('Remote app root is required.');
    }
    if (vmServicePort < 1024 || vmServicePort > 65535) {
      issues.add('VM service port must be 1024-65535.');
    }
    return issues;
  }

  QaSshConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? privateKeyPath,
    String? remoteAppRoot,
    String? remoteFlutterExecutable,
    String? remoteDisplay,
    int? vmServicePort,
    SshLaunchMethod? launchMethod,
    String? prebuiltBinaryPath,
    String? hostFingerprint,
    String? knownHostsPath,
    bool? strictHostKeyChecking,
  }) => QaSshConfig(
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    privateKeyPath: privateKeyPath ?? this.privateKeyPath,
    remoteAppRoot: remoteAppRoot ?? this.remoteAppRoot,
    remoteFlutterExecutable:
        remoteFlutterExecutable ?? this.remoteFlutterExecutable,
    remoteDisplay: remoteDisplay ?? this.remoteDisplay,
    vmServicePort: vmServicePort ?? this.vmServicePort,
    launchMethod: launchMethod ?? this.launchMethod,
    prebuiltBinaryPath: prebuiltBinaryPath ?? this.prebuiltBinaryPath,
    hostFingerprint: hostFingerprint ?? this.hostFingerprint,
    knownHostsPath: knownHostsPath ?? this.knownHostsPath,
    strictHostKeyChecking: strictHostKeyChecking ?? this.strictHostKeyChecking,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'host': host,
    'port': port,
    'username': username,
    if (privateKeyPath != null) 'privateKeyPath': privateKeyPath,
    'remoteAppRoot': remoteAppRoot,
    'remoteFlutterExecutable': remoteFlutterExecutable,
    'remoteDisplay': remoteDisplay,
    'vmServicePort': vmServicePort,
    'launchMethod': launchMethod.storageValue,
    'prebuiltBinaryPath': prebuiltBinaryPath,
    if (hostFingerprint != null) 'hostFingerprint': hostFingerprint,
    if (knownHostsPath != null) 'knownHostsPath': knownHostsPath,
    'strictHostKeyChecking': strictHostKeyChecking,
  };

  factory QaSshConfig.fromJson(Map<String, Object?> json) => QaSshConfig(
    host: (json['host'] as String?) ?? '',
    port: (json['port'] as num?)?.toInt() ?? 22,
    username: (json['username'] as String?) ?? '',
    privateKeyPath: json['privateKeyPath'] as String?,
    remoteAppRoot: (json['remoteAppRoot'] as String?) ?? '',
    remoteFlutterExecutable:
        (json['remoteFlutterExecutable'] as String?) ?? 'flutter',
    remoteDisplay: (json['remoteDisplay'] as String?) ?? ':0',
    vmServicePort: (json['vmServicePort'] as num?)?.toInt() ?? 8888,
    launchMethod: SshLaunchMethod.fromStorageValue(
      json['launchMethod'] as String?,
    ),
    prebuiltBinaryPath:
        (json['prebuiltBinaryPath'] as String?) ??
        './build/linux/x64/debug/bundle/penguin_pos',
    hostFingerprint: json['hostFingerprint'] as String?,
    knownHostsPath: json['knownHostsPath'] as String?,
    strictHostKeyChecking: (json['strictHostKeyChecking'] as bool?) ?? true,
  );
}
