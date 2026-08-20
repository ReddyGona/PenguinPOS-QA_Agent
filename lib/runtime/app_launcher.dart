import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Handles launching the PenguinPOS Flutter application process and capturing the VM Service URI.
class PenguinPosAppLauncher {
  static const defaultAppRoot =
      '/Users/reddygona/Documents/PenguinPOS/penguin_pos';

  Future<LaunchedPenguinPos> launch({
    required String appRoot,
    String flutterExecutable = 'flutter',
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
      flutterExecutable.isNotEmpty ? flutterExecutable : 'flutter',
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
    return LocalLaunchedPenguinPos(process: process, vmServiceUri: serviceUri);
  }

  Future<Uri> _waitForVmServiceUri(Process process) async {
    final lines = StreamGroup.merge(<Stream<String>>[
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()),
    ]);
    final expression = RegExp(r'https?://[^\s]+');
    final serviceUri = Completer<Uri>();
    late final StreamSubscription<String> outputSubscription;

    outputSubscription = lines.listen(
      (line) {
        // Keep application logs private by forwarding only explicit QA traces.
        if (line.startsWith('[PenguinPOS]') || line.startsWith('[IdleLock]')) {
          stderr.writeln('[PenguinPOS app] $line');
        }

        if (serviceUri.isCompleted) return;
        final match = expression.firstMatch(line);
        if (match == null) return;
        if (line.toLowerCase().contains('vm service') ||
            line.contains('is available at:')) {
          serviceUri.complete(Uri.parse(match.group(0)!));
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!serviceUri.isCompleted) {
          serviceUri.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!serviceUri.isCompleted) {
          serviceUri.completeError(
            StateError(
              'PenguinPOS exited before publishing a Dart VM service URI.',
            ),
          );
        }
      },
    );

    try {
      return await serviceUri.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          outputSubscription.cancel();
          throw TimeoutException(
            'Timed out waiting for PenguinPOS to publish a Dart VM service URI.',
          );
        },
      );
    } catch (_) {
      await outputSubscription.cancel();
      rethrow;
    }
  }
}

/// Abstract lifecycle handle for a running PenguinPOS instance.
/// Consumers use only [vmServiceUri] and [close]. The transport is invisible.
abstract class LaunchedPenguinPos {
  Uri get vmServiceUri;
  Future<void> close();
}

/// Represents a locally-launched instance of PenguinPOS.
class LocalLaunchedPenguinPos implements LaunchedPenguinPos {
  const LocalLaunchedPenguinPos({
    required this.process,
    required this.vmServiceUri,
  });

  final Process process;

  @override
  final Uri vmServiceUri;

  @override
  Future<void> close() async {
    try {
      process.kill(ProcessSignal.sigint);
      await process.exitCode.timeout(
        const Duration(seconds: 3),
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
