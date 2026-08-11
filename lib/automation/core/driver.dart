import 'dart:async';

/// Defines supported text input strategies for UI testing.
enum TextInputMode {
  /// Direct Flutter Driver text injection.
  driverDirect,

  /// Virtual key tapping on CustomQwertyPad.
  customQwertyPad,

  /// Virtual key tapping on CustomNumPad.
  customNumPad,
}

/// Security-hardened exception thrown when a string contains a character unmappable on the virtual keyboard.
///
/// To prevent secret disclosure (e.g. leaking password characters), the exception message intentionally
/// specifies position index and character classification rather than raw symbol payload.
class UnsupportedKeyboardCharacterException implements Exception {
  final int position;
  final String reason;

  const UnsupportedKeyboardCharacterException({
    required this.position,
    this.reason = 'Virtual keyboard layout cannot represent character',
  });

  @override
  String toString() =>
      'UnsupportedKeyboardCharacterException: $reason at position $position.';
}

/// Abstract driver interface decoupling test blocks from Flutter Driver execution.
abstract interface class Driver {
  Future<void> connect(
    Uri vmServiceUri, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitFor(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitForAbsent(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<String> waitForAnyKey(
    Iterable<String> keys, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<bool> hasKey(
    String key, {
    Duration timeout = const Duration(seconds: 2),
  });

  Future<bool> hasText(
    String text, {
    Duration timeout = const Duration(seconds: 2),
  });

  Future<void> enterText(
    String key,
    String text, {
    Duration timeout = const Duration(seconds: 2),
  });

  Future<void> enterTextViaVirtualKeyboard(
    String targetInputKey,
    String text, {
    String keyPrefix = 'login.qwerty',
    TextInputMode mode = TextInputMode.customQwertyPad,
  });

  Future<String?> tryGetText(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<String> getText(
    String key, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> tap(String key);

  Future<void> tapText(String text);

  Future<bool> tryTapText(
    String text, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<bool> tryTapKey(
    String key, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Sends a custom text command message to the target app's Flutter Driver extension handler.
  Future<String?> requestData(
    String message, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Instantly requests the target application to clear active SnackBars.
  /// Returns `true` if acknowledged by the target app extension, `false` otherwise.
  Future<bool> clearSnackBars();

  Future<void> close();
}
