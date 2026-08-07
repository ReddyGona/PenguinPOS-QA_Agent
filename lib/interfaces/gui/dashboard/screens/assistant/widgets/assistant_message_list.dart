import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_execution_tracker.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_model_trace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_rich_message.dart';

/// Conversation message list displaying left-aligned assistant text & right-aligned light-slate user bubbles.
class AssistantMessageList extends StatelessWidget {
  const AssistantMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.planningEvents = const <AiModelEvent>[],
    this.planningRunning = false,
    this.executionSteps = const <AiExecutionStep>[],
    this.executionSuiteTitle = '',
    this.executionProfileLabel = '',
    this.executionRunning = false,
  });

  final List<AiChatMessage> messages;
  final ScrollController scrollController;
  final List<AiModelEvent> planningEvents;
  final bool planningRunning;
  final List<AiExecutionStep> executionSteps;
  final String executionSuiteTitle;
  final String executionProfileLabel;
  final bool executionRunning;

  @override
  Widget build(BuildContext context) {
    final showExecution = executionSteps.isNotEmpty;
    final showPlanning =
        !showExecution && planningRunning && planningEvents.isNotEmpty;
    final inlineStatusCount = showExecution || showPlanning ? 1 : 0;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      itemCount: messages.length + inlineStatusCount,
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: showExecution
                ? AssistantExecutionTracker(
                    steps: executionSteps,
                    suiteTitle: executionSuiteTitle,
                    profileLabel: executionProfileLabel,
                    running: executionRunning,
                  )
                : AssistantModelTrace(
                    events: planningEvents,
                    running: planningRunning,
                  ),
          );
        }
        final message = messages[index];
        if (message.role == AiChatRole.user) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F4F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7C9C4)),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF2C302E),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }

        // Assistant messages: Rich content card or plain left-aligned text
        final richContent = message.richContent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 12),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Always show the text message
                        if (message.text.isNotEmpty)
                          SelectableText(
                            message.text,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: Color(0xFF2C302E),
                              letterSpacing: -0.1,
                            ),
                          ),
                        // Render structured rich content below the text
                        if (richContent != null) ...<Widget>[
                          if (message.text.isNotEmpty)
                            const SizedBox(height: 12),
                          AssistantRichMessage(content: richContent),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
