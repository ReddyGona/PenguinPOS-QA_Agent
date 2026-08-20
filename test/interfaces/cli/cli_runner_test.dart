import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/interfaces/cli/login_cli_handler.dart';
import 'package:penguin_pos_qa_agent/interfaces/cli/order_cli_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Execute CLI via Flutter Test Runner',
    () async {
      final rawArgs = const String.fromEnvironment('ARGS', defaultValue: '');
      if (rawArgs.isEmpty) {
        stdout.writeln(
          'No ARGS passed. Usage: flutter test test/interfaces/cli/cli_runner_test.dart --dart-define=ARGS="login --profile kpn-dev"',
        );
        return;
      }

      final args = rawArgs.split(' ').where((s) => s.isNotEmpty).toList();
      final command = args.first.toLowerCase();

      if (command == 'login') {
        final handler = LoginCliHandler();
        await handler.execute(args.skip(1).toList());
      } else if (command == 'order') {
        final handler = OrderCliHandler();
        await handler.execute(args.skip(1).toList());
      } else {
        stderr.writeln('Unknown command: $command');
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
