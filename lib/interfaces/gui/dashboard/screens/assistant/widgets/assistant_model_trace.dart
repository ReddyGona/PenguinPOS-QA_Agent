import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Live, in-chat application activity.
///
/// This intentionally looks like an assistant typing status rather than a
/// dashboard card. It reports safe application work only; private model
/// reasoning and hidden instructions are never rendered.
class AssistantModelTrace extends StatelessWidget {
  const AssistantModelTrace({
    super.key,
    required this.events,
    required this.running,
  });

  final List<AiModelEvent> events;
  final bool running;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final statuses = events
        .where((event) => event.kind == AiModelEventKind.status)
        .toList(growable: false);
    final errors = events
        .where((event) => event.kind == AiModelEventKind.error)
        .toList(growable: false);
    if (statuses.isEmpty && errors.isEmpty) return const SizedBox.shrink();

    final latestStatus = statuses.isEmpty ? null : statuses.last;
    return Semantics(
      label: 'Live assistant activity',
      child: Padding(
        padding: const EdgeInsets.only(left: 28, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final status in statuses)
              _LiveActivityLine(
                message: status.message,
                active: running && status == latestStatus,
                complete: !running || status != latestStatus,
              ),
            for (final error in errors)
              _LiveActivityLine(
                message: error.message,
                active: false,
                complete: false,
                error: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveActivityLine extends StatelessWidget {
  const _LiveActivityLine({
    required this.message,
    required this.active,
    required this.complete,
    this.error = false,
  });

  final String message;
  final bool active;
  final bool complete;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? AssistantUiTokens.error
        : active
        ? AssistantUiTokens.text
        : AssistantUiTokens.mutedText;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: active || error ? 1 : 0.68,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 15,
              width: 15,
              child: active
                  ? const Padding(
                      padding: EdgeInsets.all(1),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AssistantUiTokens.accent,
                      ),
                    )
                  : Icon(
                      error
                          ? Icons.error_outline_rounded
                          : complete
                          ? Icons.check_rounded
                          : Icons.more_horiz_rounded,
                      size: 15,
                      color: error
                          ? AssistantUiTokens.error
                          : complete
                          ? AssistantUiTokens.accent
                          : AssistantUiTokens.mutedText,
                    ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
