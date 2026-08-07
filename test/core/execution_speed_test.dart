import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/qa_agent.dart';

void main() {
  group('ExecutionSpeed & SpeedPresets', () {
    test('parses raw speed preset names correctly', () {
      expect(SpeedPreset.parse('slow'), equals(SpeedPreset.slow));
      expect(SpeedPreset.parse('SLOW'), equals(SpeedPreset.slow));
      expect(SpeedPreset.parse('medium'), equals(SpeedPreset.medium));
      expect(SpeedPreset.parse('fast'), equals(SpeedPreset.fast));
      expect(SpeedPreset.parse('invalid'), equals(SpeedPreset.fast));
      expect(SpeedPreset.parse(null), equals(SpeedPreset.fast));
    });

    test('returns correct delay durations for speed presets', () {
      const fast = ExecutionSpeed(preset: SpeedPreset.fast);
      const medium = ExecutionSpeed(preset: SpeedPreset.medium);
      const slow = ExecutionSpeed(preset: SpeedPreset.slow);
      const custom = ExecutionSpeed(
        preset: SpeedPreset.custom,
        customDelay: Duration(milliseconds: 1500),
      );

      expect(fast.delay, equals(const Duration(milliseconds: 100)));
      expect(medium.delay, equals(const Duration(milliseconds: 1000)));
      expect(slow.delay, equals(const Duration(milliseconds: 2500)));
      expect(custom.delay, equals(const Duration(milliseconds: 1500)));
    });
  });
}
