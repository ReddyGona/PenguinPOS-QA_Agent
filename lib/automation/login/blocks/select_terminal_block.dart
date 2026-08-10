import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';

/// Atomic block for waiting for terminal selection screen and tapping continue.
class SelectTerminalBlock implements AutomationBlock {
  final LoginScenario scenario;

  SelectTerminalBlock({required this.scenario});

  @override
  String get id => 'select_terminal';

  @override
  String get name => 'Select Terminal';

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.waitFor(
      scenario.terminalContinueKey,
      timeout: context.timeout,
      delay: context.speed.delay,
    );
    await context.driver.tap(
      scenario.terminalContinueKey,
      delay: context.speed.delay,
    );
  }
}
