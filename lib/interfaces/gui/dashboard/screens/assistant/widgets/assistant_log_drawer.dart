import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// DevTools-inspired terminal drawer for execution logs and captured requests.
class AssistantLogDrawer extends StatefulWidget {
  const AssistantLogDrawer({
    super.key,
    required this.activityMessages,
    required this.apiTraces,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<QaActivityMessage> activityMessages;
  final List<ApiTraceEvent> apiTraces;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<AssistantLogDrawer> createState() => _AssistantLogDrawerState();
}

class _AssistantLogDrawerState extends State<AssistantLogDrawer> {
  var _showNetwork = false;
  int? _selectedTraceId;

  @override
  void didUpdateWidget(AssistantLogDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.expanded && widget.expanded) {
      _showNetwork = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMessage = widget.activityMessages.isEmpty
        ? null
        : widget.activityMessages.last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Divider(height: 1, thickness: 1, color: Color(0xFFD7DAD6)),
        InkWell(
          onTap: widget.onToggleExpanded,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFFF5F4F1),
            child: Row(
              children: <Widget>[
                const Icon(Icons.terminal_rounded, size: 17),
                const SizedBox(width: 9),
                const Text(
                  'Terminal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                _CountBadge(label: '${widget.activityMessages.length} logs'),
                const SizedBox(width: 6),
                _CountBadge(label: '${widget.apiTraces.length} requests'),
                const SizedBox(width: 14),
                if (!widget.expanded && lastMessage != null)
                  Expanded(
                    child: Text(
                      '${lastMessage.title} — ${lastMessage.body}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B706D),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Icon(
                  widget.expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                ),
              ],
            ),
          ),
        ),
        if (widget.expanded) _buildTerminal(),
      ],
    );
  }

  Widget _buildTerminal() => Container(
    height: 330,
    color: const Color(0xFF151A18),
    child: Column(
      children: <Widget>[
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF303936))),
          ),
          child: Row(
            children: <Widget>[
              _TerminalTab(
                icon: Icons.subject_rounded,
                label: 'Logs',
                selected: !_showNetwork,
                onTap: () => setState(() => _showNetwork = false),
              ),
              const SizedBox(width: 4),
              _TerminalTab(
                icon: Icons.lan_outlined,
                label: 'Network',
                selected: _showNetwork,
                onTap: () => setState(() => _showNetwork = true),
              ),
              const Spacer(),
              Text(
                _showNetwork
                    ? '${widget.apiTraces.length} captured'
                    : '${widget.activityMessages.length} entries',
                style: const TextStyle(color: Color(0xFF9EAAA4), fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(child: _showNetwork ? _buildNetwork() : _buildLogs()),
      ],
    ),
  );

  Widget _buildLogs() {
    if (widget.activityMessages.isEmpty) {
      return const Center(
        child: Text('No terminal output yet.', style: _terminalMuted),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.activityMessages.length,
      itemBuilder: (context, index) {
        final entry = widget.activityMessages[index];
        final color = switch (entry.kind) {
          QaActivityKind.success => const Color(0xFF70D18C),
          QaActivityKind.error => const Color(0xFFFF9188),
          QaActivityKind.info => const Color(0xFF7CB7FF),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: Color(0xFFD6DED9),
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '● ',
                  style: TextStyle(color: color),
                ),
                TextSpan(
                  text: '${entry.title}: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: entry.body),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetwork() {
    if (widget.apiTraces.isEmpty) {
      return const Center(
        child: Text('No network requests captured yet.', style: _terminalMuted),
      );
    }
    final selected = widget.apiTraces.where(
      (e) => e.traceId == _selectedTraceId,
    );
    final active = selected.isEmpty ? widget.apiTraces.last : selected.first;
    return Column(
      children: <Widget>[
        _networkHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: widget.apiTraces.length,
            itemBuilder: (context, index) {
              final trace =
                  widget.apiTraces[widget.apiTraces.length - 1 - index];
              return _NetworkRow(
                trace: trace,
                selected: trace.traceId == active.traceId,
                onTap: () => setState(() => _selectedTraceId = trace.traceId),
              );
            },
          ),
        ),
        _networkDetail(active),
      ],
    );
  }

  Widget _networkHeader() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    child: Row(
      children: <Widget>[
        SizedBox(width: 42, child: Text('METHOD', style: _terminalLabel)),
        SizedBox(width: 10),
        Expanded(flex: 5, child: Text('NAME', style: _terminalLabel)),
        Expanded(child: Text('STATUS', style: _terminalLabel)),
        Expanded(child: Text('TYPE', style: _terminalLabel)),
        Expanded(flex: 2, child: Text('INITIATOR', style: _terminalLabel)),
        SizedBox(
          width: 64,
          child: Text(
            'TIME',
            textAlign: TextAlign.right,
            style: _terminalLabel,
          ),
        ),
      ],
    ),
  );

  Widget _networkDetail(ApiTraceEvent trace) => Container(
    height: 56,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0xFF101412),
      border: Border(top: BorderSide(color: Color(0xFF303936))),
    ),
    child: Text(
      '${trace.method} ${trace.route}\n${trace.transport.name.toUpperCase()} · ${trace.mode.name} · Step: ${trace.stepId}${trace.sanitizedPreview.isEmpty ? '' : ' · ${trace.sanitizedPreview}'}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: Color(0xFFC4CEC8),
      ),
    ),
  );
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.trace,
    required this.selected,
    required this.onTap,
  });
  final ApiTraceEvent trace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expectedInvalidLogin =
        trace.stepId == 'validate_invalid_credentials' &&
        trace.statusCode == 401 &&
        trace.route.contains('/login');
    final statusColor = trace.result == ApiTraceResult.success
        ? const Color(0xFF70D18C)
        : expectedInvalidLogin
        ? const Color(0xFFF3C969)
        : const Color(0xFFFF9188);
    final status = expectedInvalidLogin
        ? '401 expected'
        : trace.statusCode?.toString() ?? trace.result.name;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? const Color(0xFF26342D) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 42,
              child: Text(trace.method, style: _terminalValue),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: Text(
                trace.route,
                overflow: TextOverflow.ellipsis,
                style: _terminalValue,
              ),
            ),
            Expanded(
              child: Text(
                status,
                style: _terminalValue.copyWith(color: statusColor),
              ),
            ),
            Expanded(
              child: Text(
                trace.transport.name.toUpperCase(),
                style: _terminalValue,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                trace.stepId,
                overflow: TextOverflow.ellipsis,
                style: _terminalValue,
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${trace.durationMs} ms',
                textAlign: TextAlign.right,
                style: _terminalValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalTab extends StatelessWidget {
  const _TerminalTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? const Color(0xFFE7F2EB)
          : const Color(0xFF97A49D),
      backgroundColor: selected ? const Color(0xFF2A3A31) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFE3EBE5),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF355342),
      ),
    ),
  );
}

const _terminalMuted = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: Color(0xFF9EAAA4),
);
const _terminalLabel = TextStyle(
  fontFamily: 'monospace',
  fontSize: 10,
  fontWeight: FontWeight.w700,
  color: Color(0xFF829088),
);
const _terminalValue = TextStyle(
  fontFamily: 'monospace',
  fontSize: 11,
  color: Color(0xFFD6DED9),
);
