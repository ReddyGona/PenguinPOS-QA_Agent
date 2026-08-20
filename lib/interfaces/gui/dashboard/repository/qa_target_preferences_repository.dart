import 'dart:convert';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_target_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QaSshTarget {
  const QaSshTarget({required this.username, required this.host});
  final String username;
  final String host;
}

/// Stores non-secret SSH connection and target preferences scoped per profile.
class QaTargetPreferencesRepository implements QaTargetRepository {
  static const _usernameKey = 'ssh.username';
  static const _hostKey = 'ssh.host';
  static const _globalSshConfigKey = 'qa.ssh_config.v1';
  static const _globalTargetModeKey = 'qa.target_mode.v1';
  static const _profilesKey = 'qa.target_profiles.v1';
  static const _selectedProfileIdKey = 'qa.selected_profile_id.v1';
  static const _aiModeKey = 'qa.ai_mode.v1';
  static const _aiModelConfigKey = 'qa.ai_model_config.v1';
  static const _initialSetupCompleteKey = 'qa.initial_setup_complete.v1';
  static const _noticeDisplayModeKey = 'qa.notice_display_mode.v1';

  String _profileSshConfigKey(String profileId) =>
      'qa.ssh_config.$profileId.v1';
  String _profileTargetModeKey(String profileId) =>
      'qa.target_mode.$profileId.v1';

  @override
  Future<QaTargetMode> loadTargetMode([String? profileId]) async {
    final preferences = await SharedPreferences.getInstance();
    if (profileId != null && profileId.isNotEmpty) {
      final scoped = preferences.getString(_profileTargetModeKey(profileId));
      if (scoped != null && scoped.isNotEmpty) {
        return QaTargetMode.fromStorageValue(scoped);
      }
    }
    final mode = preferences.getString(_globalTargetModeKey);
    return mode == 'ssh' ? QaTargetMode.ssh : QaTargetMode.local;
  }

  @override
  Future<void> saveTargetMode(
    dynamic profileOrMode, [
    QaTargetMode? mode,
  ]) async {
    final preferences = await SharedPreferences.getInstance();
    if (profileOrMode is String && mode != null) {
      await preferences.setString(
        _profileTargetModeKey(profileOrMode),
        mode.storageValue,
      );
      await preferences.setString(_globalTargetModeKey, mode.storageValue);
    } else if (profileOrMode is QaTargetMode) {
      await preferences.setString(
        _globalTargetModeKey,
        profileOrMode.storageValue,
      );
    }
  }

  @override
  Future<QaSshConfig?> loadSshConfig([String? profileId]) async {
    final preferences = await SharedPreferences.getInstance();
    if (profileId != null && profileId.isNotEmpty) {
      final raw = preferences.getString(_profileSshConfigKey(profileId));
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return QaSshConfig.fromJson(decoded.cast<String, Object?>());
          }
        } catch (_) {}
      }
    }

    // Fallback to global config
    final rawGlobal = preferences.getString(_globalSshConfigKey);
    if (rawGlobal != null && rawGlobal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawGlobal);
        if (decoded is Map) {
          return QaSshConfig.fromJson(decoded.cast<String, Object?>());
        }
      } catch (_) {}
    }

    // Backwards compatibility with legacy keys
    final host = preferences.getString(_hostKey) ?? '';
    final user = preferences.getString(_usernameKey) ?? '';
    if (host.isNotEmpty && user.isNotEmpty) {
      return QaSshConfig(
        host: host,
        username: user,
        remoteAppRoot: '/home/$user/Documents/penguin_pos',
      );
    }
    return null;
  }

  @override
  Future<void> saveSshConfig(
    dynamic profileOrConfig, [
    QaSshConfig? config,
  ]) async {
    final preferences = await SharedPreferences.getInstance();
    if (profileOrConfig is String && config != null) {
      await preferences.setString(
        _profileSshConfigKey(profileOrConfig),
        jsonEncode(config.toJson()),
      );
      await preferences.setString(
        _globalSshConfigKey,
        jsonEncode(config.toJson()),
      );
      await preferences.setString(_usernameKey, config.username);
      await preferences.setString(_hostKey, config.host);
    } else if (profileOrConfig is QaSshConfig) {
      await preferences.setString(
        _globalSshConfigKey,
        jsonEncode(profileOrConfig.toJson()),
      );
      await preferences.setString(_usernameKey, profileOrConfig.username);
      await preferences.setString(_hostKey, profileOrConfig.host);
    }
  }

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

  Future<bool> hasCompletedInitialSetup() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_initialSetupCompleteKey) ?? false;
  }

  Future<void> markInitialSetupComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_initialSetupCompleteKey, true);
  }
}
