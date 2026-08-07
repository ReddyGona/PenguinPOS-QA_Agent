import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';
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
    required this.onStopSuite,
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
  final VoidCallback onStopSuite;

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
          if (widget.running) ...<Widget>[
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: widget.onStopSuite,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Stop Test Case'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
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

                final isPassed =
                    hasRun &&
                    (widget.lastExecutionPassed == true ||
                        widget.scenariosCompleted.contains(scenario.name) ||
                        widget.scenariosCompleted.contains(scenario.id));

                final isFailed =
                    hasRun &&
                    !isPassed &&
                    !widget.wasAppClosedByUser &&
                    widget.lastExecutionPassed == false &&
                    (widget.scenariosCompleted.length == index ||
                        (!widget.scenariosCompleted.contains(scenario.name) &&
                            !widget.scenariosCompleted.contains(scenario.id)));

                return ScenarioCard(
                  scenario: scenario,
                  isExpanded: isExpanded,
                  isPassed: isPassed,
                  isFailed: isFailed,
                  wasAppClosedByUser: widget.wasAppClosedByUser,
                  lastExecutionDetails: widget.lastExecutionDetails,
                  onToggleExpand: () {
                    setState(() {
                      _expandedMap[scenario.id] = !isExpanded;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
