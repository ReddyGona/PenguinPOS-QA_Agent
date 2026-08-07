import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Handles launching the PenguinPOS Flutter application process and capturing the VM Service URI.
class PenguinPosAppLauncher {
  static const defaultAppRoot =
      '/Users/reddygona/Documents/PenguinPOS/penguin_pos';

  Future<LaunchedPenguinPos> launch({
    required String appRoot,
    String? device,
    String? entity,
    String? env,
  }) async {
    final targetDevice =
        device ??
        Platform.environment['PENGUIN_POS_DEVICE'] ??
        (Platform.isMacOS
            ? 'macos'
            : Platform.isWindows
            ? 'windows'
            : 'linux');
    final targetEntity =
        entity ?? Platform.environment['PENGUIN_POS_ENTITY'] ?? 'ibo';
    final targetEnv = env ?? Platform.environment['PENGUIN_POS_ENV'] ?? 'stage';

    final process = await Process.start(
      'flutter',
      <String>[
        'run',
        '-d',
        targetDevice,
        '--dart-define=ENABLE_FLUTTER_DRIVER=true',
        '--dart-define=ENTITY=$targetEntity',
        '--dart-define=ENV=$targetEnv',
      ],
      workingDirectory: appRoot,
      mode: ProcessStartMode.normal,
    );
    final serviceUri = await _waitForVmServiceUri(process);
    return LaunchedPenguinPos(process: process, vmServiceUri: serviceUri);
  }

  Future<Uri> _waitForVmServiceUri(Process process) async {
    final lines = StreamGroup.merge(<Stream<String>>[
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    ]);
    final expression = RegExp(r'https?://[^\s]+');
    await for (final line in lines.timeout(const Duration(minutes: 2))) {
      final match = expression.firstMatch(line);
      if (match == null) continue;
      final uriString = match.group(0)!;
      if (line.toLowerCase().contains('vm service') ||
          line.contains('is available at:')) {
        return Uri.parse(uriString);
      }
    }
    throw StateError(
      'PenguinPOS exited before publishing a Dart VM service URI.',
    );
  }
}

/// Represents a running instance of PenguinPOS launched for QA automation.
class LaunchedPenguinPos {
  const LaunchedPenguinPos({required this.process, required this.vmServiceUri});

  final Process process;
  final Uri vmServiceUri;

  Future<void> close() async {
    process.kill(ProcessSignal.sigint);
    await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
  }
}

/// Merges multiple streams without external package dependencies.
abstract final class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>();
    var remaining = 0;
    for (final stream in streams) {
      remaining++;
      stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          remaining--;
          if (remaining == 0) controller.close();
        },
      );
    }
    return controller.stream;
  }
}
