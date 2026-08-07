import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

/// Card widget rendering individual scenario details, steps checkmarks, tags, and error traces.
class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.isExpanded,
    required this.isPassed,
    required this.isFailed,
    required this.wasAppClosedByUser,
    required this.lastExecutionDetails,
    required this.onToggleExpand,
  });

  final TestSuiteScenario scenario;
  final bool isExpanded;
  final bool isPassed;
  final bool isFailed;
  final bool wasAppClosedByUser;
  final String? lastExecutionDetails;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPassed
              ? const Color(0xFF86EFAC)
              : (isFailed ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
          width: isPassed || isFailed ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    isPassed
                        ? Icons.check_circle_outline_rounded
                        : (isFailed
                              ? Icons.cancel_outlined
                              : Icons.radio_button_unchecked_rounded),
                    color: isPassed
                        ? const Color(0xFF16A34A)
                        : (isFailed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF94A3B8)),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (wasAppClosedByUser && !isPassed)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (scenario.tags.isNotEmpty)
                    Row(
                      children: scenario.tags.map((tag) {
                        return Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          // Steps Details Block
          if (isExpanded) ...<Widget>[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ...scenario.stepsDescription.asMap().entries.map((entry) {
                    final stepIdx = entry.key;
                    final stepText = entry.value;
                    final isLastStep =
                        stepIdx == scenario.stepsDescription.length - 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                isPassed
                                    ? Icons.check_circle_outline
                                    : (isFailed && isLastStep
                                          ? Icons.error_outline_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded),
                                size: 16,
                                color: isPassed
                                    ? const Color(0xFF16A34A)
                                    : (isFailed && isLastStep
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  stepText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isFailed && isLastStep
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isFailed && isLastStep
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isFailed && isLastStep) ...<Widget>[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(left: 26, top: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                              child: Text(
                                lastExecutionDetails ??
                                    'Error: Order & payment step execution failed.',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFB91C1C),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
