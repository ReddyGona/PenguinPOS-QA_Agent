import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/core/execution_speed.dart';

enum SpeedSelectorVariant {
  /// Segmented button layout [ 0.5x | 1x | 2x | Turbo ] for Manual Suite headers.
  segmented,

  /// Compact dropdown menu for the AI Assistant chat bar.
  compactDropdown,
}

/// Controlled widget for selecting execution speed in Manual Suite headers and AI Assistant.
class SpeedSelectorWidget extends StatelessWidget {
  const SpeedSelectorWidget({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.variant = SpeedSelectorVariant.segmented,
    this.options = const <ExecutionSpeed>[
      ExecutionSpeed.halfX,
      ExecutionSpeed.oneX,
      ExecutionSpeed.twoX,
      ExecutionSpeed.turbo,
    ],
  });

  final ExecutionSpeed selected;
  final ValueChanged<ExecutionSpeed> onChanged;
  final bool enabled;
  final SpeedSelectorVariant variant;
  final List<ExecutionSpeed> options;

  @override
  Widget build(BuildContext context) {
    if (variant == SpeedSelectorVariant.compactDropdown) {
      return _buildCompactDropdown(context);
    }
    return _buildSegmentedButton(context);
  }

  Widget _buildSegmentedButton(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: SegmentedButton<ExecutionSpeed>(
          segments: options.map((speed) {
            return ButtonSegment<ExecutionSpeed>(
              value: speed,
              label: Text(
                speed.displayLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          selected: <ExecutionSpeed>{selected},
          onSelectionChanged: (Set<ExecutionSpeed> newSelection) {
            if (newSelection.isNotEmpty) {
              onChanged(newSelection.first);
            }
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDropdown(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: DropdownMenu<ExecutionSpeed>(
          initialSelection: selected,
          onSelected: (ExecutionSpeed? value) {
            if (value != null) {
              onChanged(value);
            }
          },
          dropdownMenuEntries: options.map((speed) {
            return DropdownMenuEntry<ExecutionSpeed>(
              value: speed,
              label: '⚡ ${speed.displayLabel}',
            );
          }).toList(),
          inputDecorationTheme: const InputDecorationTheme(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          width: 120,
        ),
      ),
    );
  }
}
