import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_keys.dart';

class IncompatibleAppException implements Exception {
  final String message;
  const IncompatibleAppException(this.message);

  @override
  String toString() => 'IncompatibleAppException: $message';
}

/// PosAutomationContract handles mode-aware preflight key verification and key builder helpers against PenguinPOS targets.
abstract final class PosAutomationContract {
  static const version = '1.0.0';

  // Key builders for CustomQwertyPad
  static String qwertyKey(String prefix, String char) => '$prefix.key.$char';
  static String qwertyShift(String prefix) => '$prefix.shift';
  static String qwertySpace(String prefix) => '$prefix.space';
  static String qwertyBackspace(String prefix) => '$prefix.backspace';
  static String qwertyDelete(String prefix) => '$prefix.delete';
  static String qwertyEnter(String prefix) => '$prefix.enter';

  // Key builders for CustomNumPad
  static String numpadDigit(String prefix, String digit) =>
      '$prefix.digit.$digit';
  static String numpadBackspace(String prefix) => '$prefix.backspace';
  static String numpadClear(String prefix) => '$prefix.clear';
  static String numpadEnter(String prefix) => '$prefix.enter';

  /// Performs preflight key presence verification matching the active [mode].
  static Future<void> verifyContract(
    Driver driver, {
    TextInputMode mode = TextInputMode.customQwertyPad,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // 1. Verify core login screen controls
    final hasLoginId = await driver.hasKey(
      PenguinPosLoginKeys.loginId,
      timeout: timeout,
    );
    if (!hasLoginId) {
      throw const IncompatibleAppException(
        'Target PenguinPOS build does not implement QA Contract v1 (missing key "${PenguinPosLoginKeys.loginId}").',
      );
    }

    // 2. Mode-aware key verification
    if (mode == TextInputMode.customQwertyPad) {
      final sampleKey = qwertyKey('login.qwerty', 'a');
      final hasVirtualKey = await driver.hasKey(
        sampleKey,
        timeout: const Duration(seconds: 2),
      );
      if (!hasVirtualKey) {
        throw IncompatibleAppException(
          'Target PenguinPOS build does not expose custom QWERTY keys (missing key "$sampleKey").',
        );
      }
    }
  }
}
