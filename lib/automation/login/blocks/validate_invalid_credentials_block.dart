import 'package:penguin_pos_qa_agent/automation/core/automation_block.dart';
import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/core/execution_context.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

/// Tests authentication failure handling when invalid credentials are submitted.
class ValidateInvalidCredentialsBlock implements AutomationBlock {
  final TextInputMode mode;
  final String keyPrefix;

  ValidateInvalidCredentialsBlock({
    this.mode = TextInputMode.customQwertyPad,
    this.keyPrefix = 'login.qwerty',
  });

  @override
  String get id => 'validate_invalid_credentials';

  @override
  String get name => 'Auth Failure Handling';

  @override
  Future<void> execute(ExecutionContext context) async {
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.loginId,
      '0000000000',
      keyPrefix: keyPrefix,
      mode: mode,
      delay: context.speed.delay,
    );
    await context.driver.enterTextViaVirtualKeyboard(
      PenguinPosLoginKeys.password,
      'invalidpassword',
      keyPrefix: keyPrefix,
      mode: mode,
      delay: context.speed.delay,
    );
    await context.driver.tap(
      PenguinPosLoginKeys.submit,
      delay: context.speed.delay,
    );
    await context.driver.waitFor(
      PenguinPosLoginKeys.loginId,
      timeout: context.timeout,
      delay: context.speed.delay,
    );
  }
}
