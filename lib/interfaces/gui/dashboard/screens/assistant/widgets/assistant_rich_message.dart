import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';

/// Renders rich structured content (plan summaries, test reports) as styled
/// cards with tables inside the chat message list.
class AssistantRichMessage extends StatelessWidget {
  const AssistantRichMessage({super.key, required this.content});

  final AiRichContent content;

  @override
  Widget build(BuildContext context) {
    return switch (content) {
      AiRichPlanSummary summary => _PlanSummaryCard(summary: summary),
      AiRichTestReport report => _TestReportCard(report: report),
      AiRichOrderReport report => _OrderReportCard(report: report),
      AiRichPlanningSummary summary => _PlanningSummaryCard(summary: summary),
    };
  }
}

class _PlanningSummaryCard extends StatefulWidget {
  const _PlanningSummaryCard({required this.summary});

  final AiRichPlanningSummary summary;

  @override
  State<_PlanningSummaryCard> createState() => _PlanningSummaryCardState();
}

class _PlanningSummaryCardState extends State<_PlanningSummaryCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9DDD8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.manage_search_rounded,
                    size: 16,
                    color: Color(0xFF658A7A),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Planning details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C302E),
                      ),
                    ),
                  ),
                  Text(
                    '${widget.summary.steps.length} steps',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF787A76),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF787A76),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final step in widget.summary.steps)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                color: Color(0xFF494C4A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Summary Card
// ---------------------------------------------------------------------------

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.summary});

  final AiRichPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9DDD8)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.playlist_add_check_rounded,
                    size: 16,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Test Plan Ready',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C302E),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE8E6E1)),

          // Metadata rows
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: <Widget>[
                _MetadataRow(label: 'Profile', value: summary.profileLabel),
                const SizedBox(height: 6),
                _MetadataRow(label: 'Workflow', value: summary.workflowLabel),
                const SizedBox(height: 6),
                _MetadataRow(
                  label: 'Scenarios',
                  value: '${summary.scenarios.length}',
                ),
              ],
            ),
          ),

          // Scenario table
          if (summary.scenarios.isNotEmpty) ...<Widget>[
            const Divider(height: 1, color: Color(0xFFE8E6E1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _ScenarioTable(scenarios: summary.scenarios),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF787A76),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C302E),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioTable extends StatelessWidget {
  const _ScenarioTable({required this.scenarios});

  final List<AiScenarioRow> scenarios;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(32),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(72),
      },
      children: <TableRow>[
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8E6E1))),
          ),
          children: <Widget>[
            _tableHeaderCell('#'),
            _tableHeaderCell('Scenario'),
            _tableHeaderCell('Status'),
          ],
        ),
        // Rows
        for (var i = 0; i < scenarios.length; i++)
          TableRow(
            decoration: i < scenarios.length - 1
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF0EEEA)),
                    ),
                  )
                : null,
            children: <Widget>[
              _tableCell('${i + 1}'),
              _tableCell(scenarios[i].name),
              _statusBadge(scenarios[i].status),
            ],
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF787A76),
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _tableCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11.5, color: Color(0xFF2C302E)),
    ),
  );

  Widget _statusBadge(String status) {
    final isPending = status.toLowerCase() == 'pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isPending
                ? const Color(0xFFE65100)
                : const Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test Report Card
// ---------------------------------------------------------------------------

class _OrderReportCard extends StatelessWidget {
  const _OrderReportCard({required this.report});

  final AiRichOrderReport report;

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = report.passed
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFEF9A9A);
    final headerColor = report.passed
        ? const Color(0xFFF1F8E9)
        : const Color(0xFFFFF3E0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  report.passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 22,
                  color: report.passed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        report.passed
                            ? '${report.passedCount} order${report.passedCount == 1 ? '' : 's'} completed'
                            : 'Order run finished with failures',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: report.passed
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFB71C1C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.suiteTitle} · ${report.profileLabel} — ${_formatDuration(report.totalDurationMs)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF494C4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E6E1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'Order results',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF494C4A),
              ),
            ),
          ),
          for (final order in report.orders)
            _OrderResultRow(order: order, formatDuration: _formatDuration),
          const Divider(height: 18, color: Color(0xFFE8E6E1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Test checks applied to every order',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF494C4A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ResultTable(
              results: report.testChecks,
              formatDuration: _formatDuration,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderResultRow extends StatelessWidget {
  const _OrderResultRow({required this.order, required this.formatDuration});

  final AiOrderResult order;
  final String Function(int ms) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            order.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: order.passed
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Order ${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C302E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.itemSummary,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF494C4A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${order.cashAmount}\n${formatDuration(order.durationMs)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF494C4A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestReportCard extends StatelessWidget {
  const _TestReportCard({required this.report});

  final AiRichTestReport report;

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: report.passed
              ? const Color(0xFFA5D6A7)
              : const Color(0xFFEF9A9A),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: report.passed
                ? const Color(0x1A4CAF50)
                : const Color(0x1AE53935),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header with pass/fail badge
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: report.passed
                  ? const Color(0xFFF1F8E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  report.passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 22,
                  color: report.passed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        report.passed ? 'Suite Passed 🎉' : 'Suite Failed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: report.passed
                              ? const Color(0xFF1B5E20)
                              : const Color(0xFFB71C1C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.suiteTitle} · ${report.profileLabel} — Completed in ${_formatDuration(report.totalDurationMs)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF494C4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE8E6E1)),

          // Result table
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _ResultTable(
              results: report.scenarioResults,
              formatDuration: _formatDuration,
            ),
          ),

          // Summary footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: <Widget>[
                _SummaryChip(
                  label: '${report.passedCount} passed',
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                ),
                const SizedBox(width: 8),
                if (report.failedCount > 0)
                  _SummaryChip(
                    label: '${report.failedCount} failed',
                    color: const Color(0xFFC62828),
                    bgColor: const Color(0xFFFFEBEE),
                  ),
                const Spacer(),
                Text(
                  'Total: ${report.scenarioResults.length} scenario${report.scenarioResults.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF787A76),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.results, required this.formatDuration});

  final List<AiScenarioResult> results;
  final String Function(int ms) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(32),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(40),
        3: FixedColumnWidth(56),
      },
      children: <TableRow>[
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE8E6E1))),
          ),
          children: <Widget>[
            _headerCell('#'),
            _headerCell('Scenario'),
            _headerCell(''),
            _headerCell('Time'),
          ],
        ),
        // Data rows
        for (var i = 0; i < results.length; i++)
          TableRow(
            decoration: i < results.length - 1
                ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF5F3EF)),
                    ),
                  )
                : null,
            children: <Widget>[
              _cell('${i + 1}'),
              _cell(results[i].name),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Icon(
                  results[i].passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 14,
                  color: results[i].passed
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                ),
              ),
              _cell(formatDuration(results[i].durationMs)),
            ],
          ),
      ],
    );
  }

  Widget _headerCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF787A76),
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _cell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11.5, color: Color(0xFF2C302E)),
    ),
  );
}
