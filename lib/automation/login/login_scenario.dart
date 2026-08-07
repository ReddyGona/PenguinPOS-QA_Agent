import 'login_keys.dart';

/// Data payload model for a login scenario execution.
class LoginScenario {
  const LoginScenario({
    required this.id,
    required this.name,
    required this.loginId,
    required this.password,
    this.terminalContinueKey = PenguinPosLoginKeys.terminalContinue,
    this.expectedKey = PenguinPosLoginKeys.homeScreen,
  });

  final String id;
  final String name;
  final String loginId;
  final String password;
  final String terminalContinueKey;
  final String expectedKey;
}
