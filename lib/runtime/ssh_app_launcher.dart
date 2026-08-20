import 'dart:async';
import 'dart:io';

import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/open_ssh_transport.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/ssh_transport.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/vm_service_probe.dart';

/// Lifecycle handle for a remotely-launched PenguinPOS instance over SSH.
class SshLaunchedPenguinPos implements LaunchedPenguinPos {
  SshLaunchedPenguinPos({
    required this.vmServiceUri,
    required this.tunnelHandle,
    required this.remotePid,
    required this.remoteStartTime,
    required this.sshConfig,
    required this.ownsRemoteProcess,
    required this.transport,
  });

  @override
  final Uri vmServiceUri;

  final SshTunnelHandle tunnelHandle;
  final int? remotePid;
  final String? remoteStartTime;
  final QaSshConfig sshConfig;
  final bool ownsRemoteProcess;
  final SshTransport transport;

  @override
  Future<void> close() async {
    // 1. Close local SSH tunnel
    try {
      await tunnelHandle.close();
    } catch (_) {}

    // 2. Kill remote PenguinPOS process group only if this session started it
    if (ownsRemoteProcess && remotePid != null) {
      try {
        final teardownScript = [
          // Verify PID has not been recycled by comparing start timestamp
          'CURRENT_START=\$(cat /proc/$remotePid/stat 2>/dev/null | awk \'{print \$22}\')',
          'if [ "\$CURRENT_START" = "${remoteStartTime ?? ''}" ] || [ -z "${remoteStartTime ?? ''}" ]; then',
          '  kill -TERM -- -$remotePid 2>/dev/null || true',
          '  for i in 1 2 3 4 5 6; do',
          '    if ! kill -0 -- -$remotePid 2>/dev/null; then break; fi',
          '    sleep 0.5',
          '  done',
          '  kill -KILL -- -$remotePid 2>/dev/null || true',
          'fi',
        ].join('\n');

        await transport.runCommand(
          sshConfig,
          teardownScript,
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {}
    }
  }
}

/// Manages remote PenguinPOS lifecycle, deterministic session discovery,
/// ELF preflights, guarded process groups, and loopback tunnels with retry.
class SshAppLauncher {
  SshAppLauncher({SshTransport? transport, VmServiceProbe? vmProbe})
    : _transport = transport ?? OpenSshTransport(),
      _vmProbe = vmProbe ?? const DefaultVmServiceProbe();

  final SshTransport _transport;
  final VmServiceProbe _vmProbe;

  /// Probes SSH connectivity, verifies remote directories, and checks ELF compatibility.
  Future<String?> testConnection(QaSshConfig config) async {
    final result = await _transport.testConnection(config);
    if (!result.success) {
      return result.errorMessage ?? 'SSH connection failed.';
    }

    if (config.launchMethod == SshLaunchMethod.prebuiltBinary) {
      final preflightError = await preflightPrebuiltBinary(config);
      if (preflightError != null) return preflightError;
    }
    return null;
  }

  /// Validates that the prebuilt binary exists, is executable, and matches target architecture.
  Future<String?> preflightPrebuiltBinary(QaSshConfig config) async {
    final fullBinaryPath =
        '${config.remoteAppRoot}/${config.prebuiltBinaryPath}';
    final script = [
      'if [ ! -x ${shellQuote(fullBinaryPath)} ]; then echo "NOT_EXEC"; exit 0; fi',
      'DEVICE_ARCH=\$(uname -m)',
      'FILE_INFO=\$(file -Lb ${shellQuote(fullBinaryPath)} 2>/dev/null || readelf -h ${shellQuote(fullBinaryPath)} 2>/dev/null || echo "UNKNOWN")',
      'echo "ARCH:\$DEVICE_ARCH|\$FILE_INFO"',
    ].join(' ; ');

    final result = await _transport.runCommand(
      config,
      script,
      timeout: const Duration(seconds: 10),
    );

    if (result.stdout.contains('NOT_EXEC')) {
      return 'Prebuilt binary does not exist or is not executable: $fullBinaryPath';
    }

    final out = result.stdout;
    if (out.contains('x86-64') || out.contains('x86_64')) {
      if (!out.contains('ARCH:x86_64')) {
        return 'Binary architecture mismatch: binary is x86_64 but device architecture is different ($out).';
      }
    } else if (out.contains('aarch64') || out.contains('ARM aarch64')) {
      if (!out.contains('ARCH:aarch64')) {
        return 'Binary architecture mismatch: binary is ARM64 but device is different ($out).';
      }
    }
    return null;
  }

  /// Probes active graphical session environment from running desktop processes.
  Future<Map<String, String>> discoverGuiSessionEnvironment(
    QaSshConfig config,
  ) async {
    final script = [
      // Find PID of running desktop compositor / X11 server owned by target user
      'PID=\$(pgrep -u "${config.username}" -f "Xorg|wayland|gnome-shell|kwin|labwc|pos" | head -n 1)',
      'if [ -n "\$PID" ] && [ -r "/proc/\$PID/environ" ]; then',
      '  tr \'\\0\' \'\\n\' < "/proc/\$PID/environ" | grep -E \'^(DISPLAY|XAUTHORITY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR|WAYLAND_DISPLAY)=\'',
      'else',
      '  echo "DISPLAY=${config.remoteDisplay}"',
      '  echo "XDG_RUNTIME_DIR=/run/user/\$(id -u)"',
      '  echo "XAUTHORITY=\$HOME/.Xauthority"',
      'fi',
    ].join('\n');

    final result = await _transport.runCommand(
      config,
      script,
      timeout: const Duration(seconds: 5),
    );

    final env = <String, String>{};
    for (final line in result.stdout.split('\n')) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          env[key] = value;
        }
      }
    }

    // Ensure fallback minimums
    env.putIfAbsent('DISPLAY', () => config.remoteDisplay);
    env.putIfAbsent(
      'XDG_RUNTIME_DIR',
      () => '/run/user/${config.username == "savo" ? "1000" : config.username}',
    );
    return env;
  }

  /// Launches PenguinPOS on remote POS and establishes a loopback-strict tunnel with retry.
  Future<SshLaunchedPenguinPos> launch({
    required QaSshConfig config,
    required String entity,
    required String env,
    void Function(ExecutionEvent event)? onProgress,
  }) async {
    void emit(
      String title,
      String message, {
      ExecutionEventLevel level = ExecutionEventLevel.info,
    }) => onProgress?.call(
      ExecutionEvent(title: title, message: message, level: level),
    );

    // 1. Connection and architecture probe
    emit(
      'Verifying SSH Connection',
      'Checking SSH connectivity to ${config.destination}.',
    );
    final probeError = await testConnection(config);
    if (probeError != null) {
      throw StateError('SSH target connection preflight failed: $probeError');
    }
    emit(
      'SSH Connection Verified',
      'Connected to ${config.destination}; remote launch prerequisites are available.',
      level: ExecutionEventLevel.success,
    );

    // 2. Discover active GUI session environment
    emit(
      'Discovering Remote GUI Session',
      'Resolving the active Linux display and desktop session for PenguinPOS.',
    );
    final sessionEnv = await discoverGuiSessionEnvironment(config);

    // 3. Launch remote process in dedicated process group with start timestamp guard
    emit(
      'Launching Remote PenguinPOS',
      'Starting PenguinPOS on the Linux target with the QA driver enabled.',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final logPath = '/tmp/penguin_pos_qa_$timestamp.log';
    final launchRecord = await launchRemoteProcess(
      config: config,
      entity: entity,
      env: env,
      sessionEnv: sessionEnv,
      logPath: logPath,
    );

    final remotePid = launchRecord.$1;
    final remoteStartTime = launchRecord.$2;
    emit(
      'Remote PenguinPOS Started',
      'Remote process started; waiting for its QA VM service.',
      level: ExecutionEventLevel.success,
    );

    // 4. Establish local loopback tunnel with retry & WebSocket getVersion verification
    emit(
      'Establishing Secure VM Tunnel',
      'Creating a loopback-only SSH tunnel and verifying the VM-service handshake.',
    );
    final tunnelResult = await _establishVerifiedTunnel(
      config: config,
      remotePid: remotePid,
      logPath: logPath,
      maxRetries: 3,
    );

    return SshLaunchedPenguinPos(
      vmServiceUri: tunnelResult.wsUri,
      tunnelHandle: tunnelResult.handle,
      remotePid: remotePid,
      remoteStartTime: remoteStartTime,
      sshConfig: config,
      ownsRemoteProcess: true,
      transport: _transport,
    );
  }

  Future<(int, String)> launchRemoteProcess({
    required QaSshConfig config,
    required String entity,
    required String env,
    required Map<String, String> sessionEnv,
    required String logPath,
  }) async {
    final envExports = <String>[
      'export PATH="\$HOME/Documents/flutter/bin:\$HOME/flutter/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"',
      for (final entry in sessionEnv.entries)
        'export ${entry.key}=${shellQuote(entry.value)}',
    ].join(' ; ');

    final pidPath =
        '/tmp/penguin_pos_qa_${logPath.split('_').last.replaceFirst('.log', '')}.pid';
    final String executionCmd;
    if (config.launchMethod == SshLaunchMethod.prebuiltBinary) {
      executionCmd = [
        'cd ${shellQuote(config.remoteAppRoot)}',
        '&&',
        'PID_FILE=${shellQuote(pidPath)}',
        '&&',
        'rm -f "\$PID_FILE"',
        '&&',
        'setsid --fork sh -c ${shellQuote('echo "\$\$" > "\$1"; shift; exec "\$@"')} sh "\$PID_FILE"',
        shellQuote(config.prebuiltBinaryPath),
        '--vm-service-port=${config.vmServicePort}',
        '--disable-service-auth-codes',
        '</dev/null',
        '> ${shellQuote(logPath)} 2>&1',
        '&&',
        'for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "\$PID_FILE" ] && break; sleep 0.1; done',
        '&&',
        'PID=\$(cat "\$PID_FILE" 2>/dev/null);',
        'START=\$(cat /proc/\$PID/stat 2>/dev/null | awk \'{print \$22}\');',
        'echo "\$PID:\$START"',
      ].join(' ');
    } else {
      executionCmd = [
        'cd ${shellQuote(config.remoteAppRoot)}',
        '&&',
        'PID_FILE=${shellQuote(pidPath)}',
        '&&',
        'rm -f "\$PID_FILE"',
        '&&',
        'setsid --fork sh -c ${shellQuote('echo "\$\$" > "\$1"; shift; exec "\$@"')} sh "\$PID_FILE"',
        shellQuote(config.remoteFlutterExecutable),
        'run',
        '-d',
        'linux',
        '--dart-define=ENABLE_FLUTTER_DRIVER=true',
        // PenguinPOS matches this compile-time value case-sensitively.
        // Domain profiles use lower-case identifiers such as `kpn`.
        '--dart-define=ENTITY=${shellQuote(entity.trim().toLowerCase())}',
        '--dart-define=ENV=${shellQuote(env.toLowerCase())}',
        '--vm-service-port=${config.vmServicePort}',
        '--disable-service-auth-codes',
        '</dev/null',
        '> ${shellQuote(logPath)} 2>&1',
        '&&',
        'for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "\$PID_FILE" ] && break; sleep 0.1; done',
        '&&',
        'PID=\$(cat "\$PID_FILE" 2>/dev/null);',
        'START=\$(cat /proc/\$PID/stat 2>/dev/null | awk \'{print \$22}\');',
        'echo "\$PID:\$START"',
      ].join(' ');
    }

    final fullScript = '$envExports ; $executionCmd';
    final result = await _transport.runCommand(
      config,
      fullScript,
      timeout: const Duration(seconds: 30),
    );

    if (result.exitCode != 0) {
      throw StateError('Failed to launch remote PenguinPOS: ${result.stderr}');
    }

    final parts = result.stdout.trim().split(':');
    final pid = int.tryParse(parts.first.trim());
    if (pid == null) {
      throw StateError(
        'Failed to capture remote PID from stdout: ${result.stdout}',
      );
    }
    final startTime = parts.length > 1 ? parts[1].trim() : '';
    return (pid, startTime);
  }

  Future<({Uri wsUri, SshTunnelHandle handle})> _establishVerifiedTunnel({
    required QaSshConfig config,
    required int remotePid,
    required String logPath,
    int maxRetries = 3,
  }) async {
    String lastError = '';

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final localPort = await _allocateLocalPort();
      SshTunnelHandle? tunnelHandle;

      try {
        tunnelHandle = await _transport.openLocalTunnel(
          config: config,
          localPort: localPort,
          remotePort: config.vmServicePort,
        );

        final wsUri = Uri.parse('ws://127.0.0.1:$localPort/ws');
        final isReady = await _pollVmServiceReadiness(
          wsUri,
          tunnelHandle,
          timeout: const Duration(seconds: 45),
        );

        if (isReady) {
          return (wsUri: wsUri, handle: tunnelHandle);
        } else {
          lastError =
              'VM service did not respond to WebSocket getVersion within timeout.';
          await tunnelHandle.close();
        }
      } catch (e) {
        lastError = e.toString();
        try {
          await tunnelHandle?.close();
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    // Fetch and redact remote error log
    final remoteLog = await _fetchRedactedRemoteLog(config, logPath);
    throw TimeoutException(
      'Remote PenguinPOS VM Service failed to become ready on port ${config.vmServicePort} after $maxRetries tunnel attempts.\n'
      'Last error: $lastError\n'
      'Remote Log ($logPath):\n$remoteLog',
    );
  }

  Future<bool> _pollVmServiceReadiness(
    Uri wsUri,
    SshTunnelHandle tunnel, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      // If tunnel process died early, exit loop immediately
      final exitCheck = await tunnel.exitCode.timeout(
        const Duration(milliseconds: 10),
        onTimeout: () => -999,
      );
      if (exitCheck != -999) {
        return false;
      }

      final verified = await _vmProbe.verifyVmService(
        wsUri,
        timeout: const Duration(seconds: 2),
      );
      if (verified) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<int> _allocateLocalPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<String> _fetchRedactedRemoteLog(
    QaSshConfig config,
    String logPath,
  ) async {
    try {
      final result = await _transport.runCommand(
        config,
        'tail -n 30 ${shellQuote(logPath)} 2>/dev/null || echo "No log file found."',
        timeout: const Duration(seconds: 5),
      );
      return _redactSensitive(result.stdout);
    } catch (_) {
      return '(Could not retrieve remote log)';
    }
  }

  static String _redactSensitive(String input) {
    return input.replaceAllMapped(
      RegExp(
        r'(password|loginId|pin|token|secret)[=:\s]+([^\s,]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[REDACTED]',
    );
  }

  static String shellQuote(String value) => OpenSshTransport.shellQuote(value);
}
