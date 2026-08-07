import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';

/// Compact, user-facing planning activity shown inline with the conversation.
/// It intentionally excludes private model reasoning and is never executable
/// test input.
class AssistantModelTrace extends StatefulWidget {
  const AssistantModelTrace({
    super.key,
    required this.events,
    required this.running,
  });

  final List<AiModelEvent> events;
  final bool running;

  @override
  State<AssistantModelTrace> createState() => _AssistantModelTraceState();
}

class _AssistantModelTraceState extends State<AssistantModelTrace> {
  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    final phaseEvents = widget.events
        .where((e) => e.kind == AiModelEventKind.status && e.phase != null)
        .toList();
    final errors = widget.events
        .where((e) => e.kind == AiModelEventKind.error)
        .map((e) => e.message)
        .toList();

    // Determine the latest completed phase for the progress indicator
    final latestPhase = phaseEvents.isNotEmpty ? phaseEvents.last.phase : null;
    final progress = phaseEvents.isNotEmpty
        ? (phaseEvents.last.progress ?? 0.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errors.isEmpty
              ? const Color(0xFFD9DDD8)
              : const Color(0xFFF0B8B2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header row with progress
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      widget.running && latestPhase != AiPlanningPhase.complete
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(
                          errors.isEmpty
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          size: 18,
                          color: errors.isEmpty
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFB42318),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.running && latestPhase != AiPlanningPhase.complete
                      ? 'Preparing your test…'
                      : errors.isEmpty
                      ? 'Plan validated'
                      : 'Error',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C302E),
                  ),
                ),
                const Spacer(),
                if (widget.running && latestPhase != AiPlanningPhase.complete)
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF658A7A),
                    ),
                  ),
              ],
            ),
          ),

          // Thin progress bar
          if (widget.running || phaseEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE8E6E1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      errors.isEmpty
                          ? const Color(0xFF658A7A)
                          : const Color(0xFFB42318),
                    ),
                  ),
                ),
              ),
            ),

          // Phase stepper rows
          if (phaseEvents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: <Widget>[
                  for (final event in phaseEvents)
                    _PhaseRow(
                      phase: event.phase!,
                      message: event.message,
                      isLatest: event == phaseEvents.last,
                      isRunning:
                          widget.running &&
                          event == phaseEvents.last &&
                          event.phase != AiPlanningPhase.complete,
                      hasError: errors.isNotEmpty && event == phaseEvents.last,
                    ),
                ],
              ),
            ),

          // Error section
          if (errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Errors',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...errors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText(
                        error,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFFB42318),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// A single row in the planning phase stepper.
class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.phase,
    required this.message,
    required this.isLatest,
    required this.isRunning,
    required this.hasError,
  });

  final AiPlanningPhase phase;
  final String message;
  final bool isLatest;
  final bool isRunning;
  final bool hasError;

  IconData get _phaseIcon => switch (phase) {
    AiPlanningPhase.parsing => Icons.text_snippet_outlined,
    AiPlanningPhase.matching => Icons.person_search_rounded,
    AiPlanningPhase.planning => Icons.auto_awesome_rounded,
    AiPlanningPhase.validating => Icons.verified_outlined,
    AiPlanningPhase.complete => Icons.check_circle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bool isDone = !isRunning || !isLatest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          // Animated icon: spinner for running phase, checkmark for done
          SizedBox(
            width: 16,
            height: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isRunning && isLatest
                  ? SizedBox(
                      key: const ValueKey<String>('spinner'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasError
                              ? const Color(0xFFB42318)
                              : const Color(0xFF658A7A),
                        ),
                      ),
                    )
                  : Icon(
                      key: ValueKey<String>('done_${phase.name}'),
                      hasError && isLatest
                          ? Icons.error_outline_rounded
                          : isDone
                          ? Icons.check_circle_rounded
                          : _phaseIcon,
                      size: 14,
                      color: hasError && isLatest
                          ? const Color(0xFFB42318)
                          : isDone
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF787A76),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                color: isLatest
                    ? const Color(0xFF2C302E)
                    : const Color(0xFF787A76),
                fontWeight: isLatest ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
