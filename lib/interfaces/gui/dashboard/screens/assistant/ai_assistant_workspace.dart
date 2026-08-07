import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_composer.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_log_drawer.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_message_list.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_top_bar.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_welcome_canvas.dart';

/// Full-screen AI Assistant Workspace for PenguinPOS QA Agent.
class AiAssistantWorkspace extends StatefulWidget {
  const AiAssistantWorkspace({
    super.key,
    required this.profiles,
    required this.activeProfile,
    required this.modelConfigured,
    required this.running,
    required this.activityMessages,
    required this.executionSteps,
    required this.executionSuiteTitle,
    required this.executionProfileLabel,
    required this.onSend,
    required this.onRunPlan,
    required this.onOpenSettings,
    required this.onExitAiMode,
    this.onRegisterAddMessage,
  });

  final List<QaProfile> profiles;
  final QaProfile activeProfile;
  final bool modelConfigured;
  final bool running;
  final List<QaActivityMessage> activityMessages;

  /// Live execution progress steps pushed from the dashboard during test runs.
  final List<AiExecutionStep> executionSteps;
  final String executionSuiteTitle;
  final String executionProfileLabel;

  final Future<AiAssistantResponse> Function(
    String input,
    List<AiChatMessage> history,
    AiModelEventCallback onEvent,
  )
  onSend;
  final ValueChanged<AiTestPlan> onRunPlan;
  final VoidCallback onOpenSettings;
  final VoidCallback onExitAiMode;

  /// Called once during initState so the parent can capture a reference to
  /// [addRichMessage] without needing a GlobalKey to the private state.
  final void Function(void Function(AiChatMessage message) addMessage)?
  onRegisterAddMessage;

  @override
  State<AiAssistantWorkspace> createState() => _AiAssistantWorkspaceState();
}

class _AiAssistantWorkspaceState extends State<AiAssistantWorkspace> {
  final List<AiChatMessage> _messages = <AiChatMessage>[];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _waiting = false;
  bool _logExpanded = false;
  final List<AiModelEvent> _modelEvents = <AiModelEvent>[];
  DateTime? _lastReasoningRefresh;
  int _slashSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.onRegisterAddMessage?.call(addRichMessage);
  }

  static const List<String> _knownSlashCommands = <String>[
    '/login',
    '/orders 3',
    '/settings',
    '/manual',
    '/kpn-dev',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredSlashCommands {
    final text = _inputController.text;
    if (!text.startsWith('/')) return const <String>[];
    final query = text.toLowerCase();
    return _knownSlashCommands
        .where((cmd) => cmd.toLowerCase().startsWith(query))
        .toList();
  }

  void _applySlashCommand(String command) {
    if (command == '/settings') {
      _inputController.clear();
      widget.onOpenSettings();
      return;
    }
    if (command == '/manual') {
      _inputController.clear();
      widget.onExitAiMode();
      return;
    }
    _inputController.text = command;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: command.length),
    );
    _send();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _waiting || widget.running) return;

    setState(() {
      _messages.add(AiChatMessage(role: AiChatRole.user, text: text));
      _inputController.clear();
      _waiting = true;
      _slashSelectedIndex = 0;
      _modelEvents.clear();
      _lastReasoningRefresh = null;
    });

    _scrollToBottom();

    try {
      final response = await widget.onSend(text, _messages, _onModelEvent);
      if (!mounted) return;
      final plan = response.plan;
      final shouldAutoRun =
          plan != null && response.state == AiPlanState.readyForConfirmation;
      final planningSteps = _modelEvents
          .where((event) => event.kind == AiModelEventKind.status)
          .map((event) => event.message)
          .toSet()
          .toList(growable: false);
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            text: shouldAutoRun
                ? '${response.message}\n\nValidated for ${plan.profileId}. Starting execution…'
                : response.message,
            richContent: planningSteps.isEmpty
                ? null
                : AiRichPlanningSummary(steps: planningSteps),
          ),
        );
        _waiting = false;
        // Planning is a transient chat activity, not a permanent panel or a
        // transcript of model reasoning.
        _modelEvents.clear();
      });
      _scrollToBottom();
      if (shouldAutoRun) widget.onRunPlan(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            text:
                'I could not prepare a safe test plan. Please try again with the target and required test details.',
          ),
        );
        _waiting = false;
        _modelEvents.clear();
      });
      _scrollToBottom();
    }
  }

  void _onModelEvent(AiModelEvent event) {
    if (!mounted) return;
    if (event.kind == AiModelEventKind.reasoning &&
        _modelEvents.isNotEmpty &&
        _modelEvents.last.kind == AiModelEventKind.reasoning) {
      final prior = _modelEvents.removeLast();
      _modelEvents.add(
        AiModelEvent(
          kind: AiModelEventKind.reasoning,
          message: '${prior.message}${event.message}',
        ),
      );
    } else {
      _modelEvents.add(event);
    }

    final now = DateTime.now();
    final shouldThrottle =
        event.kind == AiModelEventKind.reasoning &&
        _lastReasoningRefresh != null &&
        now.difference(_lastReasoningRefresh!) <
            const Duration(milliseconds: 90);
    if (!shouldThrottle) {
      _lastReasoningRefresh = now;
      setState(() {});
      _scrollToBottom();
    }
  }

  /// Called by the parent dashboard to inject a rich report message into the
  /// chat when test execution finishes.
  void addRichMessage(AiChatMessage message) {
    if (!mounted) return;
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;

    return Column(
      children: <Widget>[
        // Top 58px Bar
        AssistantTopBar(
          modelConfigured: widget.modelConfigured,
          onOpenSettings: widget.onOpenSettings,
          onExitAiMode: widget.onExitAiMode,
        ),

        // Main Center Canvas & Conversation Column (Max-width 820px)
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: hasMessages
                          ? AssistantMessageList(
                              messages: _messages,
                              scrollController: _scrollController,
                              planningEvents: _modelEvents,
                              planningRunning: _waiting,
                              executionSteps: widget.executionSteps,
                              executionSuiteTitle: widget.executionSuiteTitle,
                              executionProfileLabel:
                                  widget.executionProfileLabel,
                              executionRunning: widget.running,
                            )
                          : AssistantWelcomeCanvas(
                              onSelectBentoAction: _applySlashCommand,
                            ),
                    ),

                    // Floating Composer Section
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: AssistantComposer(
                        inputController: _inputController,
                        focusNode: _focusNode,
                        waiting: _waiting,
                        running: widget.running,
                        filteredSlashCommands: _filteredSlashCommands,
                        slashSelectedIndex: _slashSelectedIndex,
                        onSelectSlashCommand: _applySlashCommand,
                        onSlashSelectedIndexChanged: (idx) {
                          setState(() => _slashSelectedIndex = idx);
                        },
                        onSend: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Minimal Collapsed / Expandable Execution Log Drawer at Bottom
        AssistantLogDrawer(
          activityMessages: widget.activityMessages,
          expanded: _logExpanded,
          onToggleExpanded: () {
            setState(() => _logExpanded = !_logExpanded);
          },
        ),
      ],
    );
  }
}
