import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_panel.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/live_execution_timeline.dart';

/// Screen dedicated to displaying and executing Login & Terminal test cases with the 3-tab layout.
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
    required this.liveMessages,
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
  final List<QaActivityMessage> liveMessages;

  final ValueChanged<String> onLoginIdChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onRunSuite;
  final VoidCallback onStopSuite;

  @override
  State<LoginSuiteScreen> createState() => _LoginSuiteScreenState();
}

class _LoginSuiteScreenState extends State<LoginSuiteScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, bool> _expandedMap = <String, bool>{};
  late final TextEditingController _loginIdController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loginIdController = TextEditingController(text: widget.loginId);
    _passwordController = TextEditingController(text: widget.password);

    for (int i = 0; i < widget.suite.scenarios.length; i++) {
      _expandedMap[widget.suite.scenarios[i].id] = i < 2;
    }
  }

  @override
  void didUpdateWidget(LoginSuiteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) {
      _tabController.animateTo(2);
    }
    if (widget.loginId != oldWidget.loginId &&
        _loginIdController.text != widget.loginId) {
      _loginIdController.text = widget.loginId;
    }
    if (widget.password != oldWidget.password &&
        _passwordController.text != widget.password) {
      _passwordController.text = widget.password;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  void _handleRunSuite() {
    _tabController.animateTo(2);
    widget.onRunSuite();
  }

  @override
  Widget build(BuildContext context) {
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
          if (widget.running) ...<Widget>[
            OutlinedButton.icon(
              onPressed: widget.onStopSuite,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Stop Test Suite'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF155EEF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: widget.running ? null : _handleRunSuite,
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
                    Icons.login_rounded,
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
          const SizedBox(height: 16),

          // Main 3-TabBar Navigation Header
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF155EEF),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF155EEF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const <Widget>[
                Tab(
                  icon: Icon(Icons.tune_rounded, size: 18),
                  text: 'Scenario Inputs & Config',
                ),
                Tab(
                  icon: Icon(Icons.integration_instructions_outlined, size: 18),
                  text: 'Test Cases & Instructions',
                ),
                Tab(
                  icon: Icon(Icons.analytics_outlined, size: 18),
                  text: 'Output & Execution Results',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Body Content View
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                if (_tabController.index == 0) {
                  return _buildInputsConfigTab();
                } else if (_tabController.index == 1) {
                  return _buildInstructionsTab();
                } else {
                  return _buildOutputResultsTab();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsConfigTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Target Credentials & Login Profile',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure the operator credentials to be verified in the login automation suite. '
            'Credentials can also be stored permanently in Settings → Credentials.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Login ID',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _loginIdController,
                            enabled: !widget.running,
                            decoration: InputDecoration(
                              hintText: 'Enter cashier / operator ID',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                            onChanged: widget.onLoginIdChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _passwordController,
                            enabled: !widget.running,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter operator password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                            onChanged: widget.onPasswordChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Target Profile: ${widget.currentProfile.label} (${widget.currentProfile.environment}) · Entity: ${widget.currentProfile.entity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        Expanded(
          child: ListView.separated(
            itemCount: widget.suite.scenarios.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final scenario = widget.suite.scenarios[index];
              final isExpanded = _expandedMap[scenario.id] ?? false;

              return ScenarioCard(
                scenario: scenario,
                isExpanded: isExpanded,
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
    );
  }

  Widget _buildOutputResultsTab() {
    final hasRun =
        widget.lastExecutionPassed != null || widget.wasAppClosedByUser;

    if (widget.running) {
      return LiveExecutionTimeline(
        messages: widget.liveMessages,
        running: true,
      );
    }

    if (!hasRun) {
      return LiveExecutionTimeline(
        messages: widget.liveMessages,
        running: false,
      );
    }

    final isSuccess = widget.lastExecutionPassed == true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSuccess
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSuccess
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isSuccess
                            ? 'Login Suite Completed Successfully 🎉'
                            : 'Login Suite Execution Failed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSuccess
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                      if (widget.lastExecutionDuration != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${widget.lastExecutionDuration!.inSeconds}s · Scenarios: ${widget.scenariosCompleted.length}/${widget.suite.scenarios.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSuccess
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.lastExecutionDetails != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SelectableText(
                widget.lastExecutionDetails!,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Run timeline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: LiveExecutionTimeline(
              messages: widget.liveMessages,
              running: false,
            ),
          ),
        ],
      ),
    );
  }
}
