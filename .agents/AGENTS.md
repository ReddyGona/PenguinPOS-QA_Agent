# AGENTS Rules & Guidelines

- **No Hardcoded Credentials or Inputs**: NEVER hardcode default usernames, login IDs, passwords, entity names, environment names, or test payload values in generated CLI commands unless the user explicitly provides them in their prompt.
- **Dynamic Parameter Passing**: Only pass CLI flags for parameters explicitly provided by the user in their prompt.
- **Interactive Prompt Fallback**: If a required parameter (e.g. `--login-id`, `--password`, `--entity`, `--env`, or future feature inputs) is missing from the user's prompt, omit that flag. The CLI runner will interactively prompt the user for missing inputs via standard input (`stdin`) at execution time.
- **Universal Feature Scope**: This rule applies to `login` and all upcoming feature modules (e.g. Checkout, Inventory, Terminal, Orders, Payments, etc.).
