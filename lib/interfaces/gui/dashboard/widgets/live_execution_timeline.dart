import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Run-scoped progress, split into operator-friendly lifecycle sections.
/// It deliberately renders execution facts separately from static test cases.
class LiveExecutionTimeline extends StatefulWidget {
  const LiveExecutionTimeline({
    super.key,
    required this.messages,
    required this.running,
  });

  final List<QaActivityMessage> messages;
  final bool running;

  @override
  State<LiveExecutionTimeline> createState() => _LiveExecutionTimelineState();
}

class _LiveExecutionTimelineState extends State<LiveExecutionTimeline> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LiveExecutionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.messages
        .where((event) => event.title != 'Ready')
        .toList(growable: false);
    if (events.isEmpty) return const _TimelineEmpty();

    final sections = <String, List<QaActivityMessage>>{};
    for (final event in events) {
      (sections[_sectionFor(event.title)] ??= <QaActivityMessage>[]).add(event);
    }
    final children = <Widget>[];
    var eventIndex = 0;
    for (final entry in sections.entries) {
      children.add(_SectionHeader(title: entry.key));
      for (final event in entry.value) {
        final isLatest = eventIndex == events.length - 1;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _TimelineRow(
              event: event,
              isActive:
                  widget.running &&
                  isLatest &&
                  event.kind == QaActivityKind.info,
            ),
          ),
        );
        eventIndex++;
      }
      children.add(const SizedBox(height: 14));
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }

  String _sectionFor(String title) {
    final value = title.toLowerCase();
    if (value.contains('preflight') || value.contains('processing suite')) {
      return 'Preflight & configuration';
    }
    if (value.contains('ssh') ||
        value.contains('penguinpos') ||
        value.contains('vm ') ||
        value.contains('local target') ||
        value.contains('tunnel') ||
        value.contains('driver')) {
      return 'Target launch & connection';
    }
    if (value.contains('cleanup') ||
        value.contains('suite passed') ||
        value.contains('suite failed') ||
        value.contains('suite error') ||
        value.contains('stop')) {
      return 'Completion & cleanup';
    }
    return 'Test execution';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const Icon(
        Icons.account_tree_outlined,
        size: 16,
        color: Color(0xFF64748B),
      ),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
    ],
  );
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.play_circle_outline_rounded,
          size: 48,
          color: Color(0xFF94A3B8),
        ),
        SizedBox(height: 12),
        Text(
          'No Execution Run Yet',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Run the suite to see preflight, launch, driver, and test progress live.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isActive});

  final QaActivityMessage event;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final (color, icon, background) = switch (event.kind) {
      QaActivityKind.success => (
        const Color(0xFF16A34A),
        Icons.check_circle_rounded,
        const Color(0xFFF0FDF4),
      ),
      QaActivityKind.error => (
        const Color(0xFFDC2626),
        Icons.cancel_rounded,
        const Color(0xFFFEF2F2),
      ),
      QaActivityKind.info => (
        const Color(0xFF2563EB),
        Icons.radio_button_unchecked_rounded,
        const Color(0xFFFFFFFF),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isActive)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.35,
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
