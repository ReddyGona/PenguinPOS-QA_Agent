# PenguinPOS QA Agent

An automated QA execution driver, desktop GUI app, & AI agent for **PenguinPOS**. It connects via Flutter Driver / Dart VM Service to launch the application, perform user interface scenario workflows, and verify login authentication, terminal selection, and home screen navigation states across platforms (macOS, Linux, Windows).

---

## 🏗️ Multi-Interface Architecture & Directory Structure

```
PenguinPOS QA_Agent/
├── bin/                              # 🚀 ENTRYPOINTS
│   ├── qa_agent.dart                 # CLI executable launcher (`qa-agent login ...`)
│   └── qa_agent_mcp.dart             # Stdio MCP server launcher for LLMs (Gemini, Claude)
│
├── docs/                             # 📘 SPECIFICATIONS & CONTRACTS
│   └── penguin_pos_requirements.md     # App contract & stable widget key definitions
│
├── lib/                              # 💻 AGENT SOURCE CODE
│   ├── qa_agent.dart                 # Main library barrel export file
│   ├── main.dart                     # Desktop GUI launcher (window_manager)
│   │
│   ├── automation/                   # 🧪 HEADLESS AUTOMATION ENGINE & CONTRACTS
│   │   └── login/                    # Login Feature Automation
│   │       ├── login_keys.dart       # Widget key contracts (`login.id`, `home.screen`)
│   │       ├── login_runner.dart     # FlutterDriver test execution engine (run & runFullSequence)
│   │       └── login_scenario.dart   # Scenario data payload model
│   │
│   ├── interfaces/                   # 🔌 ACCESS INTERFACES (Decoupled Adapters)
│   │   ├── gui/                      # 🖥️ Desktop Flutter GUI Interface
│   │   │   ├── app/                  # QaAgentGuiApp & ThemeData
│   │   │   ├── dashboard/            # Dashboard Screen, Widgets, Models & Repositories
│   │   │   └── qa_agent_dashboard.dart # GUI facade export
│   │   ├── cli/                      # 💻 Command Line Interface Adapter
│   │   │   └── login_cli_handler.dart # CLI login parser, stdin fallback & runner
│   │   └── mcp/                      # 🤖 Model Context Protocol Adapter
│   │       ├── mcp_feature_tool.dart  # MCP tool interface & schema validation
│   │       ├── mcp_input_validator.dart
│   │       ├── mcp_server.dart        # Stdio MCP Server
│   │       └── tools/
│   │           └── login_mcp_tool.dart # LoginFeatureTool, Start/Stop session tools
│   │
│   ├── core/                         # 🧠 SHARED DOMAIN & SPEED CONTROL
│   │   ├── execution_speed.dart      # Speed controls (`fast`, `medium`, `slow`, `custom`)
│   │   ├── scenario_parser.dart      # Declarative YAML scenario parser
│   │   ├── models.dart               # StepAction, TestScenario & TestStep models
│   │   ├── result.dart               # ScenarioResult & StepResult models
│   │   └── reporting/                # JSON report generator
│   │
│   └── runtime/                      # ⚙️ PLATFORM INFRASTRUCTURE
│       ├── app_launcher.dart         # Flutter process launcher (`--dart-define` flags)
│       ├── driver_engine.dart        # Driver wrapper with step delay pacing
│       ├── qa_profile_config.dart    # Profile configurations (`ibo-stage`, `kpn-stage`, etc.)
│       └── qa_session_manager.dart   # Session manager
│
├── scenarios/                        # 📄 DECLARATIVE YAML SCENARIOS
│   └── login/                        # Login Feature Scenarios
│       ├── valid_login.yaml          # Valid login & terminal continue workflow case
│       ├── invalid_credentials.yaml  # Invalid credentials authentication failure case
│       └── empty_credentials.yaml    # Empty input validation case
│
├── test/                             # 🧪 UNIT, CONTRACT & WIDGET TESTS
│   ├── automation/login/             # Automation runner & contract tests
│   ├── interfaces/mcp/               # MCP input validator tests
│   ├── core/                         # Speed preset & scenario parser tests
│   └── widget_test.dart              # Desktop GUI dashboard widget test
│
└── README.md                         # Architecture & usage documentation
```

---

## 🏃 Running Login Scenarios via CLI

```bash
# Set PenguinPOS source directory
export PENGUIN_POS_ROOT="/Users/reddygona/Documents/PenguinPOS/penguin_pos"

# Run complete sequential login suite (Empty -> Invalid -> Valid -> Terminal Continue -> Home Screen):
# Omit flags to be prompted interactively for missing credentials:
dart run bin/qa_agent.dart login

# Control execution speed (slow: 2.5s delay per step, medium: 1s delay per step, fast: 100ms delay):
dart run bin/qa_agent.dart login --speed slow

# Run single valid login scenario at custom delay:
dart run bin/qa_agent.dart login --mode single --delay-ms 1500

# Supply parameters explicitly (only pass what was provided):
dart run bin/qa_agent.dart login \
  --speed medium \
  --entity "ibo" \
  --env "stage"
```

---

## 🤖 MCP Configuration for LLM Agents (Antigravity CLI / Gemini CLI / Claude)

**For Antigravity CLI (`agy`)**:

- Workspace: `.agents/mcp_config.json`
- Global: `~/.gemini/config/mcp_config.json`

```json
{
  "mcpServers": {
    "penguin-pos-qa": {
      "command": "flutter",
      "args": ["pub", "run", "bin/qa_agent_mcp.dart"],
      "cwd": "/Users/reddygona/Documents/PenguinPOS QA_Agent",
      "env": {
        "PENGUIN_POS_ROOT": "/Users/reddygona/Documents/PenguinPOS/penguin_pos"
      }
    }
  }
}
```

> **Tip:** Type `/mcp` in `agy` to verify server connectivity.

### LLM Tool Parameters & Behavior

```json
{
  "qa_session_id": "session-12345",
  "login_id": "9999999999",
  "password": "my-test-password",
  "speed": "slow",
  "check_all_scenarios": true
}
```

The agent executes:

1. `penguin_pos_start_qa_session`: Launches app with trusted profile defaults (`ibo-stage`).
2. `penguin_pos_login`: Fills credentials, checks empty/invalid validations, handles terminal selection continue button (`login.terminal.continue`), and verifies navigation into Home Screen (`home.screen`).
3. `penguin_pos_stop_qa_session`: Safely closes the app instance when finished.
