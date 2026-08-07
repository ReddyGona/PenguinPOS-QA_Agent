import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';

/// Inline execution progress tracker shown in the chat during test runs.
/// Displays a progress bar and a live scenario checklist with animated
/// transitions as each scenario completes.
class AssistantExecutionTracker extends StatelessWidget {
  const AssistantExecutionTracker({
    super.key,
    required this.steps,
    required this.suiteTitle,
    required this.profileLabel,
    required this.running,
  });

  final List<AiExecutionStep> steps;
  final String suiteTitle;
  final String profileLabel;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final latest = steps.last;
    final progress = latest.progressFraction;
    final completedCount = latest.completedScenarios;
    final totalCount = latest.totalScenarios;

    // Build a deduplicated scenario list (latest status per scenario name)
    final scenarioMap = <String, AiExecutionStep>{};
    for (final step in steps) {
      scenarioMap[step.scenarioName] = step;
    }
    final scenarioList = scenarioMap.values.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9DDD8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: <Widget>[
                if (running)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        running
                            ? 'Running $suiteTitle'
                            : '$suiteTitle Complete',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C302E),
                        ),
                      ),
                      Text(
                        '$profileLabel · $completedCount / $totalCount scenarios',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF787A76),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF658A7A),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE8E6E1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF658A7A),
                  ),
                ),
              ),
            ),
          ),

          // Scenario checklist
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: <Widget>[
                for (final step in scenarioList) _ScenarioStepRow(step: step),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioStepRow extends StatelessWidget {
  const _ScenarioStepRow({required this.step});

  final AiExecutionStep step;

  String _formatElapsed(int? ms) {
    if (ms == null) return '';
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          // Status icon
          SizedBox(
            width: 16,
            height: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (step.status) {
                AiScenarioStatus.running => SizedBox(
                  key: const ValueKey<String>('running'),
                  width: 14,
                  height: 14,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF658A7A),
                    ),
                  ),
                ),
                AiScenarioStatus.passed => Icon(
                  key: const ValueKey<String>('passed'),
                  Icons.check_circle_rounded,
                  size: 14,
                  color: const Color(0xFF16A34A),
                ),
                AiScenarioStatus.failed => Icon(
                  key: const ValueKey<String>('failed'),
                  Icons.cancel_rounded,
                  size: 14,
                  color: const Color(0xFFE53935),
                ),
                AiScenarioStatus.skipped => Icon(
                  key: const ValueKey<String>('skipped'),
                  Icons.remove_circle_outline_rounded,
                  size: 14,
                  color: const Color(0xFF787A76),
                ),
                AiScenarioStatus.pending => Icon(
                  key: const ValueKey<String>('pending'),
                  Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: const Color(0xFFBDBDBD),
                ),
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.scenarioName,
              style: TextStyle(
                fontSize: 11.5,
                color: step.status == AiScenarioStatus.pending
                    ? const Color(0xFFBDBDBD)
                    : const Color(0xFF2C302E),
                fontWeight: step.status == AiScenarioStatus.running
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ),
          if (step.elapsedMs != null)
            Text(
              _formatElapsed(step.elapsedMs),
              style: const TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                color: Color(0xFF787A76),
              ),
            ),
          if (step.status == AiScenarioStatus.running && step.elapsedMs == null)
            const Text(
              'running…',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF658A7A),
              ),
            ),
        ],
      ),
    );
  }
}
