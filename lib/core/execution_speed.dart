/// Execution speed mode for controlling the pace of driver interaction.
enum SpeedPreset {
  fast,
  medium,
  slow,
  custom;

  /// Parses a string representation ('fast', 'medium', 'slow', 'custom', '0.5x', '1x', '2x', 'turbo') into a [SpeedPreset].
  static SpeedPreset parse(String? raw) {
    if (raw == null) return SpeedPreset.fast;
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'slow' => SpeedPreset.slow,
      'medium' => SpeedPreset.medium,
      'fast' => SpeedPreset.fast,
      '0.5x' || 'half' => SpeedPreset.custom,
      '1x' => SpeedPreset.fast,
      '2x' || 'turbo' => SpeedPreset.custom,
      'custom' => SpeedPreset.custom,
      _ => SpeedPreset.fast,
    };
  }
}

/// Helper class encapsulating execution speed configurations and delay calculation.
class ExecutionSpeed {
  const ExecutionSpeed({this.preset = SpeedPreset.fast, this.customDelay});

  final SpeedPreset preset;
  final Duration? customDelay;

  // Predefined static instances
  static const oneX = ExecutionSpeed(preset: SpeedPreset.fast);
  static const halfX = ExecutionSpeed(
    preset: SpeedPreset.custom,
    customDelay: Duration(milliseconds: 200),
  );
  static const twoX = ExecutionSpeed(
    preset: SpeedPreset.custom,
    customDelay: Duration(milliseconds: 50),
  );
  static const turbo = ExecutionSpeed(
    preset: SpeedPreset.custom,
    customDelay: Duration.zero,
  );
  static const medium = ExecutionSpeed(preset: SpeedPreset.medium);
  static const slow = ExecutionSpeed(preset: SpeedPreset.slow);

  /// Parses a string representation ('turbo', '2x', 'fast', 'medium', 'slow', '0.5x') into an [ExecutionSpeed].
  static ExecutionSpeed parse(String? raw) {
    if (raw == null) return ExecutionSpeed.oneX;
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'turbo' || 'turbomode' || 'turbo mode' => ExecutionSpeed.turbo,
      '2x' || 'double speed' => ExecutionSpeed.twoX,
      '0.5x' || 'half' || 'half speed' => ExecutionSpeed.halfX,
      'fast' || 'very fast' || '1x' => ExecutionSpeed.oneX,
      'medium' => ExecutionSpeed.medium,
      'slow' => ExecutionSpeed.slow,
      _ => ExecutionSpeed.oneX,
    };
  }

  /// Returns the actual duration to delay between driver actions.
  Duration get delay {
    if (customDelay != null) return customDelay!;
    return switch (preset) {
      SpeedPreset.fast => const Duration(milliseconds: 100),
      SpeedPreset.medium => const Duration(milliseconds: 1000),
      SpeedPreset.slow => const Duration(milliseconds: 2500),
      SpeedPreset.custom => const Duration(milliseconds: 500),
    };
  }

  /// Human-readable API name for the speed mode (e.g. 'fast', 'medium', 'slow', 'custom').
  String get name => preset.name;

  /// Display alias label for GUI speed controls (e.g. '0.5x', '1x', '2x', 'Turbo').
  String get displayLabel {
    if (customDelay == const Duration(milliseconds: 200)) return '0.5x';
    if (customDelay == const Duration(milliseconds: 50)) return '2x';
    if (customDelay == Duration.zero) return 'Turbo';
    if (preset == SpeedPreset.fast && customDelay == null) return '1x';
    if (preset == SpeedPreset.medium) return 'Medium (1s)';
    if (preset == SpeedPreset.slow) return 'Slow (2.5s)';
    return preset.name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExecutionSpeed &&
          runtimeType == other.runtimeType &&
          preset == other.preset &&
          customDelay == other.customDelay;

  @override
  int get hashCode => preset.hashCode ^ customDelay.hashCode;
}
