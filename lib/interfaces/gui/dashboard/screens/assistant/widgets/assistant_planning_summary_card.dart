import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Collapsed, user-facing summary of planning and validation work.
///
/// It deliberately contains only safe activity labels, never private model
/// reasoning or hidden instructions.
class AssistantPlanningSummaryCard extends StatefulWidget {
  const AssistantPlanningSummaryCard({super.key, required this.summary});

  final AiRichPlanningSummary summary;

  @override
  State<AssistantPlanningSummaryCard> createState() =>
      _AssistantPlanningSummaryCardState();
}

class _AssistantPlanningSummaryCardState
    extends State<AssistantPlanningSummaryCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AssistantUiTokens.subtleSurface,
        borderRadius: AssistantUiTokens.compactRadius,
        border: Border.all(color: AssistantUiTokens.subtleBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            borderRadius: AssistantUiTokens.compactRadius,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.manage_search_rounded,
                    size: 16,
                    color: AssistantUiTokens.accent,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Planning details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AssistantUiTokens.text,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.summary.steps.length} steps',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AssistantUiTokens.mutedText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final step in widget.summary.steps)
                          _PlanningStepRow(label: step),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PlanningStepRow extends StatelessWidget {
  const _PlanningStepRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: AssistantUiTokens.success,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AssistantUiTokens.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
