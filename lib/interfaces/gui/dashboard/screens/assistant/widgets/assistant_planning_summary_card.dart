import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// A small, expandable transcript of safe application preparation activity.
/// It is intentionally text-first so completed activity remains part of the
/// chat conversation instead of becoming a dashboard-style card.
class AssistantPlanningSummaryCard extends StatefulWidget {
  const AssistantPlanningSummaryCard({super.key, required this.summary});

  final AiRichPlanningSummary summary;

  @override
  State<AssistantPlanningSummaryCard> createState() =>
      _AssistantPlanningSummaryCardState();
}

class _AssistantPlanningSummaryCardState
    extends State<AssistantPlanningSummaryCard> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final stepCount = widget.summary.steps.length;
    final elapsedLabel = _formatElapsed(widget.summary.elapsedMs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 15,
                  color: AssistantUiTokens.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  elapsedLabel == null
                      ? 'Preparation activity · $stepCount checks'
                      : 'Worked for $elapsedLabel · $stepCount checks',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AssistantUiTokens.secondaryText,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: AssistantUiTokens.mutedText,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, top: 3, bottom: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final entry in widget.summary.steps.indexed)
                        _PlanningStepLine(
                          label: entry.$2,
                          failed: widget.summary.failedStep == entry.$1,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String? _formatElapsed(int? elapsedMs) {
    if (elapsedMs == null || elapsedMs < 0) return null;
    if (elapsedMs < 1000) return '<1s';
    final totalSeconds = (elapsedMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return minutes == 0 ? '${seconds}s' : '${minutes}m ${seconds}s';
  }
}

class _PlanningStepLine extends StatelessWidget {
  const _PlanningStepLine({required this.label, this.failed = false});

  final String label;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            failed ? Icons.error_outline_rounded : Icons.check_rounded,
            size: 14,
            color: failed ? AssistantUiTokens.error : AssistantUiTokens.accent,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: failed
                    ? AssistantUiTokens.error
                    : AssistantUiTokens.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
