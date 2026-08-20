import 'package:shared_preferences/shared_preferences.dart';

class QaStoredCredentials {
  const QaStoredCredentials({
    this.loginId = '',
    this.password = '',
    this.unlockPin = '',
  });

  final String loginId;
  final String password;
  final String unlockPin;

  bool get hasLoginCredentials => loginId.isNotEmpty && password.isNotEmpty;
}

/// Stores local QA credentials by profile.
///
/// Uses SharedPreferences with an in-memory fallback for headless CLI and test execution.
class QaCredentialVault {
  static final Map<String, String> _inMemoryFallback = <String, String>{};

  String _key(String profileId, String field) => 'qa.profile.$profileId.$field';

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<QaStoredCredentials> read(String profileId) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return QaStoredCredentials(
        loginId: prefs.getString(_key(profileId, 'login_id')) ?? '',
        password: prefs.getString(_key(profileId, 'password')) ?? '',
        unlockPin: prefs.getString(_key(profileId, 'unlock_pin')) ?? '',
      );
    }
    return QaStoredCredentials(
      loginId: _inMemoryFallback[_key(profileId, 'login_id')] ?? '',
      password: _inMemoryFallback[_key(profileId, 'password')] ?? '',
      unlockPin: _inMemoryFallback[_key(profileId, 'unlock_pin')] ?? '',
    );
  }

  Future<void> write(String profileId, QaStoredCredentials credentials) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      try {
        await prefs.setString(_key(profileId, 'login_id'), credentials.loginId);
        await prefs.setString(
          _key(profileId, 'password'),
          credentials.password,
        );
        await prefs.setString(
          _key(profileId, 'unlock_pin'),
          credentials.unlockPin,
        );
      } catch (_) {}
    }
    _inMemoryFallback[_key(profileId, 'login_id')] = credentials.loginId;
    _inMemoryFallback[_key(profileId, 'password')] = credentials.password;
    _inMemoryFallback[_key(profileId, 'unlock_pin')] = credentials.unlockPin;
  }

  Future<String> readAiApiKey() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      return prefs.getString('qa.ai.api_key') ?? '';
    }
    return _inMemoryFallback['qa.ai.api_key'] ?? '';
  }

  Future<void> writeAiApiKey(String apiKey) async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      try {
        await prefs.setString('qa.ai.api_key', apiKey);
      } catch (_) {}
    }
    _inMemoryFallback['qa.ai.api_key'] = apiKey;
  }
}
