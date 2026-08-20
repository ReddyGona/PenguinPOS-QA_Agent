import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';

/// Read-only test definition card. Execution state belongs exclusively to the
/// Output tab, so instructions cannot be accidentally presented as results.
class ScenarioCard extends StatelessWidget {
  const ScenarioCard({
    super.key,
    required this.scenario,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final TestSuiteScenario scenario;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  const Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xFF64748B),
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
                  ...scenario.stepsDescription.map((stepText) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.radio_button_unchecked_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  stepText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
