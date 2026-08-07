import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Minimal collapsed 38px execution log drawer at bottom that expands into a full event stream log panel.
class AssistantLogDrawer extends StatelessWidget {
  const AssistantLogDrawer({
    super.key,
    required this.activityMessages,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<QaActivityMessage> activityMessages;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final hasEvents = activityMessages.isNotEmpty;
    final lastMessage = hasEvents ? activityMessages.last : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Divider(height: 1, thickness: 1, color: Color(0xFFC7C9C4)),
        InkWell(
          onTap: onToggleExpanded,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFFF6F4F0),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.terminal_rounded,
                  size: 16,
                  color: Color(0xFF494C4A),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Execution log',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C302E),
                  ),
                ),
                const SizedBox(width: 10),
                if (hasEvents)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE4DF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${activityMessages.length} events',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF182A22),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                if (lastMessage != null && !expanded)
                  Expanded(
                    child: Text(
                      '${lastMessage.title} — ${lastMessage.body}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF787A76),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: const Color(0xFF494C4A),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            height: 180,
            color: Colors.white,
            child: hasEvents
                ? ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: activityMessages.length,
                    itemBuilder: (context, index) {
                      final msg = activityMessages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _kindBadge(msg.kind),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    msg.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C302E),
                                    ),
                                  ),
                                  Text(
                                    msg.body,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF494C4A),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      'No execution events recorded yet.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF787A76)),
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _kindBadge(QaActivityKind kind) {
    final color = switch (kind) {
      QaActivityKind.success => const Color(0xFF16A34A),
      QaActivityKind.error => const Color(0xFFDC2626),
      QaActivityKind.info => const Color(0xFF2563EB),
    };
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
