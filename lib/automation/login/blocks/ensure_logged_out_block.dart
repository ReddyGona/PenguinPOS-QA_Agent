import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

/// Resets application session state back to Login screen.
class EnsureLoggedOutBlock implements AutomationBlock {
  @override
  String get id => 'ensure_logged_out';

  @override
  String get name => 'Session Reset';

  @override
  Future<void> execute(ExecutionContext context) async {
    final initialState = await context.driver.waitForAnyKey([
      PenguinPosLoginKeys.loginId,
      PenguinPosLoginKeys.homeScreen,
    ], timeout: context.timeout);

    if (initialState == PenguinPosLoginKeys.loginId) {
      return;
    }

    final hasKeyedLogout = await context.driver.hasKey(
      PenguinPosLoginKeys.logoutButton,
      timeout: const Duration(seconds: 2),
    );
    if (hasKeyedLogout) {
      await context.driver.tap(
        PenguinPosLoginKeys.logoutButton,
        delay: context.speed.delay,
      );
    } else {
      await context.driver.tapText('LOGOUT', delay: context.speed.delay);
    }
    await context.driver.waitFor(
      PenguinPosLoginKeys.logoutConfirm,
      timeout: context.timeout,
    );
    await context.driver.tap(
      PenguinPosLoginKeys.logoutConfirm,
      delay: context.speed.delay,
    );
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
      delay: context.speed.delay,
    );
  }
}
