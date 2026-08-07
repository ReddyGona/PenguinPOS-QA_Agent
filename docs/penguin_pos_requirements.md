# PenguinPOS QA runtime contract

This QA repository contains no application tests. PenguinPOS must expose a
debug-only Flutter Driver endpoint and the following stable keys before the
external agent can execute the login scenario.

## Required QA-only application hook

Add `flutter_driver` as a development dependency and gate the extension in
`lib/main.dart` before `runApp`:

```dart
import 'package:flutter_driver/driver_extension.dart';

if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
  enableFlutterDriverExtension();
}
```

Run the QA build with:

```sh
flutter run -d linux --dart-define=ENABLE_FLUTTER_DRIVER=true
```

Never enable this flag in the production `.deb`.

## Required stable keys

Add these to `lib/features/login/widgets/login_widget_desktop.dart`:

```dart
AppTextField(key: const ValueKey('login.id'), ...)
AppTextField(key: const ValueKey('login.password'), ...)
PrimaryButton(key: const ValueKey('login.submit'), ...)
```

Add the final key to the `Continue` `PrimaryButton` in
`terminal_configurations_widget_desktop.dart`:

```dart
key: const ValueKey('login.terminal.continue'),
```

`AppTextField` and `PrimaryButton` already inherit the `key` constructor from
`StatefulWidget`/`StatelessWidget`, so their public APIs do not need changing.

## Dart MCP configuration for an LLM

Configure the official Dart MCP server separately for the PenguinPOS workspace:

```json
{
  "mcpServers": {
    "dart": {
      "command": "dart",
      "args": ["mcp-server", "--force-roots-fallback"]
    }
  }
}
```

The LLM should inspect the widget tree before an action and use the keys above.
This QA repository's CLI is the deterministic replay path; the Dart MCP server
is the live inspection and interactive-driver path.
