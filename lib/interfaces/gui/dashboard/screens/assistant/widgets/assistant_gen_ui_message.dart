import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';

/// Renders the approved, declarative QA chat catalog.
///
/// This accepts only [QaGenUiDocument], which has already rejected arbitrary
/// widget names, URLs, routes with query values, and unknown enum values.
class AssistantGenUiMessage extends StatelessWidget {
  const AssistantGenUiMessage({super.key, required this.document});

  final QaGenUiDocument document;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final component in document.components) ...<Widget>[
          _GenUiComponentCard(component: component),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GenUiComponentCard extends StatelessWidget {
  const _GenUiComponentCard({required this.component});

  final QaGenUiComponent component;

  @override
  Widget build(BuildContext context) {
    final isFailure =
        component.type == QaGenUiComponentType.timeoutNotice ||
        component.passed == false;
    final border = isFailure
        ? const Color(0xFFE9A5A1)
        : const Color(0xFFD9DDD8);
    final tint = isFailure ? const Color(0xFFFFF7F6) : const Color(0xFFFDFBF7);

    return Container(
      key: ValueKey<String>('qa_gen_ui_${component.type.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _headerIcon(component),
                size: 18,
                color: _headerColor(component),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  component.title,
                  style: const TextStyle(
                    color: Color(0xFF2C302E),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (component.profileLabel != null ||
              component.workflowLabel != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              <String>[
                if (component.workflowLabel != null) component.workflowLabel!,
                if (component.profileLabel != null) component.profileLabel!,
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF787A76)),
            ),
          ],
          if (component.summary != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              component.summary!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B504C)),
            ),
          ],
          if (component.steps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _TimelineChain(steps: component.steps),
          ],
          if (component.apiEvents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final event in component.apiEvents)
              _ApiSequenceRow(event: event),
          ],
          if (component.type == QaGenUiComponentType.timeoutNotice &&
              component.timeoutResult != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${_resultLabel(component.timeoutResult!)}${component.timeoutBudgetMs == null ? '' : ' (${_elapsed(component.timeoutBudgetMs!)} budget)'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB42318)),
            ),
          ],
        ],
      ),
    );
  }

  IconData _headerIcon(QaGenUiComponent item) => switch (item.type) {
    QaGenUiComponentType.loginPlan => Icons.login_rounded,
    QaGenUiComponentType.orderPlan => Icons.receipt_long_rounded,
    QaGenUiComponentType.stepTimeline => Icons.account_tree_outlined,
    QaGenUiComponentType.apiSequence => Icons.swap_horiz_rounded,
    QaGenUiComponentType.timeoutNotice => Icons.timer_off_outlined,
    QaGenUiComponentType.resultSummary =>
      item.passed == false ? Icons.cancel_rounded : Icons.check_circle_rounded,
  };

  Color _headerColor(QaGenUiComponent item) =>
      item.type == QaGenUiComponentType.timeoutNotice || item.passed == false
      ? const Color(0xFFB42318)
      : const Color(0xFF2E7D32);
}

class _TimelineChain extends StatelessWidget {
  const _TimelineChain({required this.steps});

  final List<QaGenUiStep> steps;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 20,
            child: CustomPaint(painter: _DottedTreeLinePainter()),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final step in steps) _TimelineRow(step: step),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step});

  final QaGenUiStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _statusIcon(step.status),
                size: 16,
                color: _statusColor(step.status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      step.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF2C302E),
                      ),
                    ),
                    if (step.detail != null)
                      Text(
                        step.detail!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF787A76),
                        ),
                      ),
                  ],
                ),
              ),
              if (step.durationMs != null)
                Text(
                  _elapsed(step.durationMs!),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF4B504C),
                  ),
                ),
            ],
          ),
          if (step.children.isNotEmpty)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: CustomPaint(painter: _DottedTreeLinePainter()),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        children: [
                          for (final child in step.children)
                            _TimelineRow(step: child),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DottedTreeLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8C2BB)
      ..strokeWidth = 1.4;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApiSequenceRow extends StatelessWidget {
  const _ApiSequenceRow({required this.event});

  final QaGenUiApiEvent event;

  @override
  Widget build(BuildContext context) {
    final success = event.result == QaGenUiApiResult.success;
    final expectedInvalidLogin =
        event.stepId == 'validate_invalid_credentials' &&
        event.statusCode == 401 &&
        event.endpoint.contains('/login');
    final statusColor = success
        ? const Color(0xFF2E7D32)
        : expectedInvalidLogin
        ? const Color(0xFF9A6700)
        : const Color(0xFFB42318);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                event.method,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.endpoint,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                  ),
                ),
              ),
              Text(
                _elapsed(event.durationMs),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text(
              '${event.transport.toUpperCase()} · ${_capitalize(event.mode)} · ${expectedInvalidLogin ? 'Expected 401' : event.statusCode ?? _resultLabel(event.result)}',
              style: TextStyle(
                fontSize: 10.5,
                color: success ? const Color(0xFF5B6F60) : statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(QaGenUiStepStatus status) => switch (status) {
  QaGenUiStepStatus.pending => Icons.radio_button_unchecked_rounded,
  QaGenUiStepStatus.running => Icons.autorenew_rounded,
  QaGenUiStepStatus.passed => Icons.check_circle_rounded,
  QaGenUiStepStatus.failed => Icons.cancel_rounded,
  QaGenUiStepStatus.skipped => Icons.remove_circle_outline_rounded,
};

Color _statusColor(QaGenUiStepStatus status) => switch (status) {
  QaGenUiStepStatus.pending => const Color(0xFF8C918B),
  QaGenUiStepStatus.running => const Color(0xFF7C3AED),
  QaGenUiStepStatus.passed => const Color(0xFF2E7D32),
  QaGenUiStepStatus.failed => const Color(0xFFB42318),
  QaGenUiStepStatus.skipped => const Color(0xFF787A76),
};

String _elapsed(int ms) =>
    ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _resultLabel(QaGenUiApiResult result) => switch (result) {
  QaGenUiApiResult.success => 'Success',
  QaGenUiApiResult.httpError => 'HTTP error',
  QaGenUiApiResult.connectTimeout => 'Connection timed out',
  QaGenUiApiResult.sendTimeout => 'Request upload timed out',
  QaGenUiApiResult.receiveTimeout => 'Server response timed out',
  QaGenUiApiResult.connectionError => 'Connection failure',
  QaGenUiApiResult.cancelled => 'Request cancelled',
  QaGenUiApiResult.unexpectedError => 'Unexpected error',
};
