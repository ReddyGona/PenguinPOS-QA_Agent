/// Execution speed mode for controlling the pace of driver interaction.
enum SpeedPreset {
  fast,
  medium,
  slow,
  custom;

  /// Parses a string representation ('fast', 'medium', 'slow', 'custom') into a [SpeedPreset].
  static SpeedPreset parse(String? raw) {
    if (raw == null) return SpeedPreset.fast;
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'slow' => SpeedPreset.slow,
      'medium' => SpeedPreset.medium,
      'fast' => SpeedPreset.fast,
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

  /// Human-readable label for the speed mode.
  String get name => preset.name;
}
