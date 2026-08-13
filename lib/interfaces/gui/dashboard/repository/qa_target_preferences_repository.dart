import 'dart:convert';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
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
  static const _profilesKey = 'qa.target_profiles.v1';
  static const _selectedProfileIdKey = 'qa.selected_profile_id.v1';
  static const _aiModeKey = 'qa.ai_mode.v1';
  static const _aiModelConfigKey = 'qa.ai_model_config.v1';
  static const _initialSetupCompleteKey = 'qa.initial_setup_complete.v1';
  static const _noticeDisplayModeKey = 'qa.notice_display_mode.v1';

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

  Future<List<QaProfile>> loadProfiles() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return QaProfile.values;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return QaProfile.values;
      final profiles = decoded
          .whereType<Map>()
          .map((profile) => QaProfile.fromJson(profile.cast<String, Object?>()))
          .where(
            (profile) =>
                profile.id.isNotEmpty &&
                profile.label.isNotEmpty &&
                profile.entity.isNotEmpty &&
                profile.environment.isNotEmpty,
          )
          .toList();
      return profiles.isEmpty ? QaProfile.values : profiles;
    } catch (_) {
      return QaProfile.values;
    }
  }

  Future<void> saveProfiles(List<QaProfile> profiles) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<String?> loadSelectedProfileId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedProfileIdKey);
  }

  Future<void> saveSelectedProfileId(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedProfileIdKey, profileId);
  }

  Future<bool> loadAiModeEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_aiModeKey) ?? true;
  }

  Future<void> saveAiModeEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_aiModeKey, enabled);
  }

  Future<QaTestNoticeDisplayMode> loadNoticeDisplayMode() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_noticeDisplayModeKey);
    return QaTestNoticeDisplayMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => QaTestNoticeDisplayMode.warningsAndErrors,
    );
  }

  Future<void> saveNoticeDisplayMode(QaTestNoticeDisplayMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_noticeDisplayModeKey, mode.name);
  }

  Future<AiModelConfig> loadAiModelConfig() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_aiModelConfigKey);
    if (raw == null || raw.isEmpty) return const AiModelConfig();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AiModelConfig();
      return AiModelConfig.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const AiModelConfig();
    }
  }

  Future<void> saveAiModelConfig(AiModelConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_aiModelConfigKey, config.encode());
  }

  /// Tracks whether the user has saved at least one reusable QA preference.
  /// This is deliberately separate from the built-in profile presets: presets
  /// are examples, while this value records an intentional user setup.
  Future<bool> hasCompletedInitialSetup() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_initialSetupCompleteKey) ?? false;
  }

  Future<void> markInitialSetupComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_initialSetupCompleteKey, true);
  }
}
