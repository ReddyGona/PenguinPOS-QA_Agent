/// Execution target modes supported by the PenguinPOS QA Agent.
enum QaTargetMode {
  /// Local machine execution (macOS / Linux host).
  local,

  /// Remote execution on a physical POS terminal over SSH.
  ssh;

  String get storageValue => switch (this) {
    QaTargetMode.local => 'local',
    QaTargetMode.ssh => 'ssh',
  };

  static QaTargetMode fromStorageValue(String? value) => switch (value) {
    'ssh' => QaTargetMode.ssh,
    _ => QaTargetMode.local,
  };
}
