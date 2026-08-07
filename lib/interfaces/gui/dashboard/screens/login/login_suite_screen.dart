import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';

/// Screen dedicated to displaying and executing Login & Terminal test cases matching the design mockup.
class LoginSuiteScreen extends StatefulWidget {
  const LoginSuiteScreen({
    super.key,
    required this.suite,
    required this.currentProfile,
    required this.loginId,
    required this.password,
    required this.targetMode,
    required this.flutterPath,
    required this.appRoot,
    required this.running,
    required this.lastExecutionPassed,
    required this.lastExecutionDuration,
    required this.lastExecutionDetails,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.onProfileChanged,
    required this.onLoginIdChanged,
    required this.onPasswordChanged,
    required this.onRunSuite,
  });

  final TestSuiteItem suite;
  final QaProfile currentProfile;
  final String loginId;
  final String password;
  final QaTargetMode targetMode;
  final String flutterPath;
  final String appRoot;

  final bool running;
  final bool? lastExecutionPassed;
  final Duration? lastExecutionDuration;
  final String? lastExecutionDetails;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;

  final ValueChanged<QaProfile> onProfileChanged;
  final ValueChanged<String> onLoginIdChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onRunSuite;

  @override
  State<LoginSuiteScreen> createState() => _LoginSuiteScreenState();
}

class _LoginSuiteScreenState extends State<LoginSuiteScreen> {
  final Map<String, bool> _expandedMap = <String, bool>{};

  @override
  void initState() {
    super.initState();
    // Default: expand scenario 1 & 2, collapse 3 to match mockup
    for (int i = 0; i < widget.suite.scenarios.length; i++) {
      _expandedMap[widget.suite.scenarios[i].id] = i < 2;
    }
  }

  bool get _allExpanded =>
      widget.suite.scenarios.every((s) => _expandedMap[s.id] == true);

  void _toggleExpandAll() {
    final nextState = !_allExpanded;
    setState(() {
      for (final s in widget.suite.scenarios) {
        _expandedMap[s.id] = nextState;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRun =
        widget.lastExecutionPassed != null || widget.wasAppClosedByUser;

    return QaPanel(
      titleWidget: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.suite.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.currentProfile.label} · ${widget.targetMode == QaTargetMode.local ? "Local Machine" : "SSH Target"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.running ? null : widget.onRunSuite,
            icon: widget.running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              widget.running ? 'Running Suite...' : 'Run Suite',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Description Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.suite.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Executable: ${widget.flutterPath} · App: ${widget.appRoot}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Scenarios Header & Expand/Collapse All Control
          Row(
            children: <Widget>[
              QaSectionTitle(
                'Scenarios & Execution Steps (${widget.suite.scenarios.length})',
              ),
              const Spacer(),
              InkWell(
                onTap: _toggleExpandAll,
                child: Row(
                  children: <Widget>[
                    Icon(
                      _allExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 16,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _allExpanded ? 'Collapse All' : 'Expand All',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scenarios Cards List
          Expanded(
            child: ListView.separated(
              itemCount: widget.suite.scenarios.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final scenario = widget.suite.scenarios[index];
                final isExpanded = _expandedMap[scenario.id] ?? false;

                // Scenario state logic
                final isPassed =
                    hasRun &&
                    (widget.lastExecutionPassed == true ||
                        widget.scenariosCompleted.contains(scenario.name) ||
                        widget.scenariosCompleted.contains(scenario.id));

                final isFailed =
                    hasRun &&
                    !isPassed &&
                    widget.lastExecutionPassed == false &&
                    (widget.scenariosCompleted.length == index ||
                        (!widget.scenariosCompleted.contains(scenario.name) &&
                            !widget.scenariosCompleted.contains(scenario.id)));

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors
                        .white, // Card remains clean white when expanded or collapsed
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPassed
                          ? const Color(0xFF86EFAC)
                          : (isFailed
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0)),
                      width: isPassed || isFailed ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Card Header
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedMap[scenario.id] = !isExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                isPassed
                                    ? Icons.check_circle_outline_rounded
                                    : (isFailed
                                          ? Icons.cancel_outlined
                                          : Icons
                                                .radio_button_unchecked_rounded),
                                color: isPassed
                                    ? const Color(0xFF16A34A)
                                    : (isFailed
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF94A3B8)),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                scenario.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isFailed
                                      ? const Color(0xFF7F1D1D)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Wrap(
                                spacing: 6,
                                children: scenario.tags
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '#$tag',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Card Steps Details (if expanded)
                      if (isExpanded) ...<Widget>[
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ...scenario.stepsDescription.asMap().entries.map((
                                entry,
                              ) {
                                final stepIdx = entry.key;
                                final stepText = entry.value;
                                final isStepFailed =
                                    isFailed &&
                                    stepIdx ==
                                        scenario.stepsDescription.length - 1;

                                final (stepIcon, stepColor) = isPassed
                                    ? (
                                        Icons.check_box_outlined,
                                        const Color(0xFF16A34A),
                                      )
                                    : (isStepFailed
                                          ? (
                                              Icons.error_outline_rounded,
                                              const Color(0xFFDC2626),
                                            )
                                          : (
                                              Icons
                                                  .check_box_outline_blank_rounded,
                                              const Color(0xFFCBD5E1),
                                            ));

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    bottom: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Icon(
                                            stepIcon,
                                            size: 16,
                                            color: stepColor,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              stepText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isStepFailed
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isStepFailed
                                                    ? const Color(0xFF991B1B)
                                                    : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Red Code/Log Error Trace Box for Failed Step
                                      if (isStepFailed) ...<Widget>[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                            left: 26,
                                            top: 4,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFCA5A5),
                                            ),
                                          ),
                                          child: Text(
                                            widget.lastExecutionDetails ??
                                                'Error: Test step execution failed.',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: Color(0xFFB91C1C),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
