import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_order_report_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_plan_summary_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_planning_summary_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_test_report_card.dart';

/// Selects the presentation that matches a structured assistant response.
///
/// Content models stay in the AI layer; each visual card lives in its own
/// widget so the chat renderer remains small and easy to extend.
class AssistantRichMessage extends StatelessWidget {
  const AssistantRichMessage({super.key, required this.content});

  final AiRichContent content;

  @override
  Widget build(BuildContext context) {
    return switch (content) {
      AiRichPlanSummary summary => AssistantPlanSummaryCard(summary: summary),
      AiRichTestReport report => AssistantTestReportCard(report: report),
      AiRichOrderReport report => AssistantOrderReportCard(report: report),
      AiRichPlanningSummary summary => AssistantPlanningSummaryCard(
        summary: summary,
      ),
    };
  }
}
