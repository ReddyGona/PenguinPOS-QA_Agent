/// Stable widget keys forming the login QA contract with PenguinPOS.
abstract final class PenguinPosLoginKeys {
  static const loginId = 'login.id';
  static const password = 'login.password';
  static const submit = 'login.submit';
  static const terminalContinue = 'login.terminal.continue';
  static const homeScreen = 'home.screen';
  static const logoutButton = 'logout.button';
  static const logoutConfirm = 'logout.confirm';
  static const idleWidget = 'idle_timeout.widget';
  static const idlePinInput = 'idle_timeout.pin_input';
  static const idleUnlock = 'idle_timeout.unlock';
  static const idleNumpadPrefix = 'idle_timeout.numpad';

  static String idleNumpadDigit(String digit) =>
      '$idleNumpadPrefix.digit.$digit';
}
