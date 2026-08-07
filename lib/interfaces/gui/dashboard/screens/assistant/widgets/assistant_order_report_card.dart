import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_report_widgets.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// Per-order outcome report, including the checks run against each order.
class AssistantOrderReportCard extends StatelessWidget {
  const AssistantOrderReportCard({super.key, required this.report});

  final AiRichOrderReport report;

  @override
  Widget build(BuildContext context) {
    return AssistantReportCard(
      passed: report.passed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AssistantReportHeader(
            passed: report.passed,
            title: report.passed
                ? '${report.passedCount} order${report.passedCount == 1 ? '' : 's'} completed'
                : 'Order run finished with failures',
            subtitle:
                '${report.suiteTitle} · ${report.profileLabel} — ${formatAssistantDuration(report.totalDurationMs)}',
          ),
          const Divider(height: 1, color: AssistantUiTokens.divider),
          const _SectionLabel('Order results', top: 12, bottom: 6),
          for (final order in report.orders) _OrderResultRow(order: order),
          const Divider(height: 18, color: AssistantUiTokens.divider),
          const _SectionLabel(
            'Test checks applied to every order',
            top: 0,
            bottom: 6,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AssistantScenarioResultTable(
              results: report.testChecks,
              formatDuration: formatAssistantDuration,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.top, required this.bottom});

  final String label;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AssistantUiTokens.secondaryText,
        ),
      ),
    );
  }
}

class _OrderResultRow extends StatelessWidget {
  const _OrderResultRow({required this.order});

  final AiOrderResult order;

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
                ? AssistantUiTokens.success
                : AssistantUiTokens.error,
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
                    color: AssistantUiTokens.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.itemSummary,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AssistantUiTokens.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${order.cashAmount}\n${formatAssistantDuration(order.durationMs)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AssistantUiTokens.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
