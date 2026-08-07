import 'package:shared_preferences/shared_preferences.dart';

class QaSshTarget {
  const QaSshTarget({required this.username, required this.host});
  final String username;
  final String host;
}

/// Stores only the non-secret SSH connection label for the desktop GUI.
class QaTargetPreferencesRepository {
  static const _usernameKey = 'ssh.username';
  static const _hostKey = 'ssh.host';

  Future<QaSshTarget> loadSshTarget() async {
    final preferences = await SharedPreferences.getInstance();
    return QaSshTarget(
      username: preferences.getString(_usernameKey) ?? '',
      host: preferences.getString(_hostKey) ?? '',
    );
  }

  Future<void> saveSshTarget(QaSshTarget target) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_usernameKey, target.username);
    await preferences.setString(_hostKey, target.host);
  }
}
