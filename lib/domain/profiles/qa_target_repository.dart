import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';

/// Repository interface for loading and saving target execution configuration
/// (target mode and SSH parameters) scoped per profile.
abstract class QaTargetRepository {
  /// Loads the target mode for the specified profile (with fallback to default).
  Future<QaTargetMode> loadTargetMode(String profileId);

  /// Saves the target mode for the specified profile.
  Future<void> saveTargetMode(String profileId, QaTargetMode mode);

  /// Loads the SSH configuration for the specified profile (with fallback to default).
  Future<QaSshConfig?> loadSshConfig(String profileId);

  /// Saves the SSH configuration for the specified profile.
  Future<void> saveSshConfig(String profileId, QaSshConfig config);
}
