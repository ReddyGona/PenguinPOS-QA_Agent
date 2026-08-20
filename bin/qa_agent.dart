import 'dart:io';

import 'package:penguin_pos_qa_agent/interfaces/cli/login_cli_handler.dart';
import 'package:penguin_pos_qa_agent/interfaces/cli/order_cli_handler.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final command = args.first.toLowerCase();

  switch (command) {
    case 'login':
      final handler = LoginCliHandler();
      await handler.execute(args.skip(1).toList());
      break;

    case 'order':
      final handler = OrderCliHandler();
      await handler.execute(args.skip(1).toList());
      break;

    case '--help':
    case '-h':
    case 'help':
      _printUsage();
      break;

    default:
      stderr.writeln('Unknown command: "$command"\n');
      _printUsage();
      exitCode = 64;
      break;
  }
}

void _printUsage() {
  stdout.writeln('''
PenguinPOS QA Agent CLI

Usage:
  qa-agent <command> [options]

Commands:
  login    Automate login verification, validation checks, and terminal selection.
  order    Automate start sale, SKU item scanning, cart sync, and cash checkout.

Options for `login`:
  --profile PROFILE            Target QA Profile ID (e.g. kpn-dev, ibo-stage). Default: ibo-stage
  --app-root PATH              Path to PenguinPOS application repository root.
  --flutter-executable PATH    Path to Flutter binary executable.
  --login-id ID                Cashier login ID. (Prompts if omitted)
  --password PASSWORD          Cashier password. (Prompts securely if omitted)
  --unlock-pin PIN             4-digit register unlock PIN.

Options for `order`:
  --profile PROFILE            Target QA Profile ID (e.g. kpn-dev, ibo-dev). Default: kpn-dev
  --app-root PATH              Path to PenguinPOS application repository root.
  --orders-count N             Number of back-to-back orders to place. Default: 1
  --items JSON_OR_SKU          JSON array of items (e.g. '[{"skuCode":"10000021","quantity":2}]') or SKU string ("10000021:2").
  --login-id ID                Optional cashier ID to pre-authenticate if app is on login screen.
  --password PASSWORD          Optional cashier password.
  --unlock-pin PIN             Optional register unlock PIN.
''');
}
