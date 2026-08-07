# AGENTS Rules & Guidelines

- **No Hardcoded Credentials or Inputs**: NEVER hardcode default usernames, login IDs, passwords, entity names, environment names, or test payload values in generated CLI commands or UI code unless the user explicitly provides them in their prompt.
- **Dynamic Parameter Passing**: Only pass CLI flags and configuration values for parameters explicitly provided by the user in their prompt or auto-detected by system tools.
- **Interactive Prompt Fallback**: If a required parameter (e.g. `--login-id`, `--password`, `--entity`, `--env`, or future feature inputs) is missing from the user's prompt, omit that flag. The CLI runner will interactively prompt the user for missing inputs via standard input (`stdin`) at execution time.
- **Universal Feature Scope**: This rule applies to `login` and all upcoming feature modules (e.g. Checkout, Inventory, Terminal, Orders, Payments, etc.).
- **Always Use Package Imports**: ALWAYS use absolute package imports (e.g., `import 'package:penguin_pos_qa_agent/...'`) for project files inside `lib/` instead of relative imports (e.g., `import '../../...'`).
- **Repository Formatting**: Before verification, run `dart format .` from the project root so every Dart file follows the same formatter output. Do not run `dart format` only on a hand-picked file list unless a full repository format is impossible.
- **Modular GUI Architecture**: Keep the Flutter Desktop GUI modular and separated by features:
  - `lib/interfaces/gui/onboarding/`: Setup wizard and onboarding screens.
  - `lib/interfaces/gui/dashboard/`: Dashboard shell, models, repositories, and widgets (`side_nav.dart`, `qa_panel.dart`, `qa_activity_panel.dart`).
  - `lib/interfaces/gui/dashboard/screens/`: Feature test suite screens (e.g. `login/login_suite_screen.dart`).
- **Dynamic Path Auto-Detection**: Do not hardcode Flutter SDK or PenguinPOS app root paths. Always use `PathDetector` auto-detection with fallback for user selection.
