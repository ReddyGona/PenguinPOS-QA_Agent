import 'dart:async';

import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/models/qa_gen_ui.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/providers/openai_compatible_provider.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_mapper.dart';
import 'package:penguin_pos_qa_agent/application/execution/unified_execution_service.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_metrics.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/automation/core/qa_test_notice.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_activity_panel.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/api_activity_panel.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/side_nav.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/login/login_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/order_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/qa_settings_screen.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';

/// Coordinates dashboard configuration, test execution, and the AI workspace.
///
/// Feature-specific presentation remains in the suite and assistant widgets.
/// This screen owns only the state that has to be shared between those views.
class QaDashboardScreen extends StatefulWidget {
  const QaDashboardScreen({super.key});

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  final _preferences = QaTargetPreferencesRepository();
  final _credentialVault = QaCredentialVault();
  final _executionService = UnifiedExecutionService();

  bool _preferencesLoaded = false;
  bool _showFirstRunSetupPrompt = false;
  bool _showSettingsScreen = false;

  QaTargetMode _targetMode = QaTargetMode.local;
  QaSshConfig? _sshConfig;
  String _flutterPath = 'flutter';
  String _appRoot = '';
  List<QaProfile> _profiles = QaProfile.values;
  QaProfile _profile = QaProfile.values.first;
  String _loginId = '';
  String _password = '';

  String _selectedSuiteId = 'login_terminal';
  OrderScenario _orderScenario = OrderScenario.sampleScenario;
  bool _aiModeEnabled = true;
  final List<AiChatMessage> _aiChatMessages = <AiChatMessage>[];
  AiPendingRequest? _pendingAssistantRequest;
  bool _aiPlanningWaiting = false;
  PlanningRequestHandle? _activePlanningHandle;

  bool get _hasActiveWork => _running || _aiPlanningWaiting;
  AiModelConfig _aiModelConfig = const AiModelConfig();
  QaTestNoticeDisplayMode _noticeDisplayMode =
      QaTestNoticeDisplayMode.warningsAndErrors;

  bool _aiModelConnected = false;
  int _modelConnectionGeneration = 0;

  bool _running = false;
  bool _stopRequested = false;
  Future<void>? _activeAiExecution;
  Duration? _lastExecutionDuration;
  bool? _lastExecutionPassed;
  String? _lastExecutionDetails;
  bool _wasAppClosedByUser = false;
  List<String> _scenariosCompletedSoFar = <String>[];
  OrderRunResult? _lastOrderRunResult;
  List<ApiTraceEvent> _apiTraces = const <ApiTraceEvent>[];

  // The runner can emit several events and telemetry snapshots for one driver
  // action. Keep those facts, but render them together so UI rebuilds never
  // become part of the execution critical path.
  static const _dashboardUpdateInterval = Duration(milliseconds: 150);
  Timer? _dashboardUpdateTimer;
  final List<QaActivityMessage> _pendingMessages = <QaActivityMessage>[];
  final List<String> _pendingCompletedScenarios = <String>[];
  final List<ExecutionEvent> _pendingExecutionEvents = <ExecutionEvent>[];
  List<ApiTraceEvent>? _pendingApiTraces;

  // Layer 3: Live execution progress tracking for the AI workspace.
  final _executionSteps = <AiExecutionStep>[];
  String _executionSuiteTitle = '';
  String _executionProfileLabel = '';
  final _executionStopwatch = Stopwatch();

  final _messages = <QaActivityMessage>[
    QaActivityMessage(
      'Ready',
      'QA Assistant is ready. Configure a reusable profile in Settings when needed.',
      QaActivityKind.info,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedTargetPreferences();
  }

  Future<void> _loadSavedTargetPreferences() async {
    final profiles = await _preferences.loadProfiles();
    final selectedProfileId = await _preferences.loadSelectedProfileId();
    final selectedProfile = profiles.firstWhere(
      (profile) => profile.id == selectedProfileId,
      orElse: () => profiles.first,
    );
    final targetMode = await _preferences.loadTargetMode(selectedProfile.id);
    final sshConfig = await _preferences.loadSshConfig(selectedProfile.id);
    var hasCompletedInitialSetup = await _preferences
        .hasCompletedInitialSetup();
    final aiModeEnabled = await _preferences.loadAiModeEnabled();
    final aiModelConfig = await _preferences.loadAiModelConfig();
    final noticeDisplayMode = await _preferences.loadNoticeDisplayMode();
    final credentials = await _credentialVault.read(selectedProfile.id);
    // Existing users configured before this preference was introduced should
    // not see first-run setup again simply because the marker is new.
    if (!hasCompletedInitialSetup &&
        selectedProfileId != null &&
        (credentials.loginId.isNotEmpty ||
            credentials.password.isNotEmpty ||
            credentials.unlockPin.isNotEmpty)) {
      await _preferences.markInitialSetupComplete();
      hasCompletedInitialSetup = true;
    }

    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _profile = selectedProfile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _targetMode = targetMode;
      _sshConfig = sshConfig;
      _aiModelConfig = aiModelConfig;
      _noticeDisplayMode = noticeDisplayMode;
      _aiModeEnabled = aiModeEnabled;
      _preferencesLoaded = true;
      _showFirstRunSetupPrompt = !hasCompletedInitialSetup;
    });
    unawaited(_refreshAiModelConnection(aiModelConfig));
    if (!hasCompletedInitialSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showFirstRunSetupPrompt) {
          _openFirstRunSetupDialog();
        }
      });
    }
    _refreshDetectedPaths();
  }

  /// Connectivity is deliberately checked separately from saved settings: a
  /// base URL and model name do not mean the server is running or reachable.
  Future<void> _refreshAiModelConnection(AiModelConfig config) async {
    final generation = ++_modelConnectionGeneration;
    if (!config.isConfigured) {
      if (mounted) setState(() => _aiModelConnected = false);
      return;
    }

    try {
      final apiKey = await _credentialVault.readAiApiKey();
      await OpenAiCompatibleProvider(
        config: config,
        apiKey: apiKey,
      ).listModels();
      if (!mounted || generation != _modelConnectionGeneration) return;
      setState(() => _aiModelConnected = true);
    } catch (_) {
      if (!mounted || generation != _modelConnectionGeneration) return;
      setState(() => _aiModelConnected = false);
    }
  }

  /// Path checks touch the local file system and must not delay the first AI
  /// screen. The runner receives the detected values before it is invoked.
  Future<void> _refreshDetectedPaths() async {
    final flutterPath = await PathDetector.detectFlutterPath();
    final appRoot = await PathDetector.detectAppRoot();
    if (!mounted) return;
    setState(() {
      _flutterPath = flutterPath;
      _appRoot = appRoot;
    });
  }

  Future<void> _selectProfile(QaProfile profile) async {
    final credentials = await _credentialVault.read(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loginId = credentials.loginId;
      _password = credentials.password;
    });
    await _preferences.saveSelectedProfileId(profile.id);
  }

  Future<void> _setAiModeEnabled(bool enabled) async {
    if (!enabled && _hasActiveWork) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Active Task Running'),
          content: const Text(
            'A QA test execution or model planning request is currently running. Leaving AI mode will stop active work.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('stay'),
              child: const Text('Keep running and stay here'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD92D20),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop('stop'),
              child: const Text('Stop execution and leave'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (choice != 'stop') return;
      await _stopActiveWork();
    }
    setState(() => _aiModeEnabled = enabled);
    await _preferences.saveAiModeEnabled(enabled);
  }

  Future<void> _stopActiveWork() async {
    _activePlanningHandle?.cancel();
    _activePlanningHandle = null;
    if (_running) {
      await _stopRunningSuite();
      // Wait until the runner has converted the app-quit signal into a
      // complete result and rendered the pass/fail report.
      await _activeAiExecution;
    }
    if (!mounted) return;
    setState(() {
      _aiPlanningWaiting = false;
    });
  }

  void _openFirstRunSetupDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: <Widget>[
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF7C3AED),
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Welcome to QA Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: const SizedBox(
          width: 410,
          child: Text(
            'Reusable environment, credentials/PIN, and optional local/cloud model are configured in Settings.',
            style: TextStyle(
              height: 1.5,
              fontSize: 13.5,
              color: Color(0xFF475569),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: <Widget>[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _openSettingsDialog();
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text(
              'Open Settings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettingsDialog() {
    setState(() => _showSettingsScreen = true);
  }

  void _openSupportDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.help_outline_rounded, color: Color(0xFF155EEF)),
            SizedBox(width: 10),
            Text('PenguinPOS Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'PenguinPOS QA Agent v0.1.0',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Automated execution driver & desktop GUI app for PenguinPOS testing.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopRunningSuite() async {
    if (!_running || _stopRequested) return;

    setState(() => _stopRequested = true);
    _addMessage(
      'Stop Requested',
      'Stopping the active test case and closing the PenguinPOS instance launched by QA.',
      QaActivityKind.info,
    );
    await _executionService.requestStop();
  }

  void _recordCompletedScenario(String scenarioName) {
    _pendingCompletedScenarios.add(scenarioName);
    _scheduleDashboardUpdate();
  }

  void _applyCompletedScenario(String scenarioName) {
    if (!_scenariosCompletedSoFar.contains(scenarioName)) {
      _scenariosCompletedSoFar.add(scenarioName);
    }
    final activeSuite = TestSuiteItem.availableSuites.firstWhere(
      (s) => s.id == _selectedSuiteId,
      orElse: () => TestSuiteItem.availableSuites.first,
    );
    final totalScenarios = activeSuite.scenarios.length;

    // Update or add the completed step
    final existingIdx = _executionSteps.indexWhere(
      (s) => s.scenarioName == scenarioName,
    );
    final step = AiExecutionStep(
      scenarioName: scenarioName,
      status: AiScenarioStatus.passed,
      elapsedMs: _executionStopwatch.elapsedMilliseconds,
      totalScenarios: totalScenarios,
      completedScenarios: _scenariosCompletedSoFar.length,
    );
    if (existingIdx >= 0) {
      _executionSteps[existingIdx] = step;
    } else {
      _executionSteps.add(step);
    }
  }

  void _recordExecutionEvent(ExecutionEvent event) {
    _addMessage(event.title, event.message, switch (event.level) {
      ExecutionEventLevel.success => QaActivityKind.success,
      ExecutionEventLevel.error => QaActivityKind.error,
      ExecutionEventLevel.info => QaActivityKind.info,
    });

    _pendingExecutionEvents.add(event);
    _scheduleDashboardUpdate();
  }

  void _applyExecutionEvent(ExecutionEvent event) {
    final idx = _executionSteps.indexWhere(
      (s) => s.scenarioName == event.title,
    );
    if (idx < 0 || _executionSteps[idx].status != AiScenarioStatus.pending) {
      return;
    }
    _executionSteps[idx] = AiExecutionStep(
      scenarioName: event.title,
      status: AiScenarioStatus.running,
      detail: event.message,
      totalScenarios: _executionSteps[idx].totalScenarios,
      completedScenarios: _scenariosCompletedSoFar.length,
    );
  }

  void _queueApiTraces(List<ApiTraceEvent> traces) {
    // Each collector callback contains the complete cumulative trace list, so
    // retaining only the newest snapshot cannot drop a trace.
    _pendingApiTraces = List<ApiTraceEvent>.unmodifiable(traces);
    _scheduleDashboardUpdate();
  }

  void _scheduleDashboardUpdate() {
    if (!mounted || _dashboardUpdateTimer != null) return;
    _dashboardUpdateTimer = Timer(
      _dashboardUpdateInterval,
      _flushDashboardUpdates,
    );
  }

  void _flushDashboardUpdates() {
    _dashboardUpdateTimer?.cancel();
    _dashboardUpdateTimer = null;
    if (!mounted) {
      _pendingMessages.clear();
      _pendingCompletedScenarios.clear();
      _pendingExecutionEvents.clear();
      _pendingApiTraces = null;
      return;
    }
    if (_pendingMessages.isEmpty &&
        _pendingCompletedScenarios.isEmpty &&
        _pendingExecutionEvents.isEmpty &&
        _pendingApiTraces == null) {
      return;
    }
    setState(() {
      _messages.addAll(_pendingMessages);
      _pendingMessages.clear();
      for (final scenario in _pendingCompletedScenarios) {
        _applyCompletedScenario(scenario);
      }
      _pendingCompletedScenarios.clear();
      for (final event in _pendingExecutionEvents) {
        _applyExecutionEvent(event);
      }
      _pendingExecutionEvents.clear();
      final traces = _pendingApiTraces;
      if (traces != null) _apiTraces = traces;
      _pendingApiTraces = null;
    });
  }

  Future<AiAssistantResponse> _respondToAi(
    String input,
    List<AiChatMessage> history,
    AiModelEventCallback onEvent,
  ) async {
    _activePlanningHandle?.cancel();
    final handle = PlanningRequestHandle(
      generationId: DateTime.now().microsecondsSinceEpoch,
    );
    _activePlanningHandle = handle;

    void safeOnEvent(AiModelEvent event) {
      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        return;
      }
      onEvent(event);
    }

    try {
      final apiKey = await _credentialVault.readAiApiKey();
      final provider = _aiModelConfig.isConfigured
          ? OpenAiCompatibleProvider(config: _aiModelConfig, apiKey: apiKey)
          : null;

      final orchestrator = AiOrchestrator(
        profiles: _profiles,
        activeProfile: _profile,
        provider: provider,
      );

      final response = await orchestrator.respond(
        input: input,
        history: history,
        pendingRequest: _pendingAssistantRequest,
        cancelToken: handle.cancelToken,
        onEvent: safeOnEvent,
      );

      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        throw const OperationCanceledException(
          'Cancelled stale planning request.',
        );
      }

      setState(() {
        _pendingAssistantRequest = response.pendingRequest;
      });

      return response;
    } catch (e) {
      if (handle.generationId != _activePlanningHandle?.generationId ||
          handle.isCancelled) {
        throw const OperationCanceledException(
          'Cancelled stale planning request.',
        );
      }
      rethrow;
    }
  }

  /// AI plans configure the same portable command as the Manual form. Profile
  /// resolution happens here; all safety and runtime checks remain in the
  /// unified execution service.
  Future<void> _runAiPlan(AiTestPlan plan) async {
    if (_running) return;
    final profile = _profileForId(plan.profileId);
    if (profile.id.isEmpty) {
      _addMessage(
        'Execution Blocked',
        'The target profile in this plan is no longer configured.',
        QaActivityKind.error,
      );
      return;
    }

    setState(() {
      _profile = profile;
      _selectedSuiteId = plan.isOrder ? 'order_checkout' : 'login_terminal';
      if (plan.isOrder) {
        _orderScenario = OrderScenario(
          id: 'ai_${profile.id}_order_cash',
          name: 'AI planned Order & Cash Payment',
          items: plan.items,
          ordersCount: plan.ordersCount,
          inputSourceMode: InputSourceMode.uiForm,
          uiCustomMode: plan.itemStrategy == AiItemStrategy.perOrder
              ? UiCustomMode.perIteration
              : UiCustomMode.common,
          perIterationItems: plan.perIterationItems,
        );
      }
    });
    await _preferences.saveSelectedProfileId(profile.id);
    _addMessage(
      'Plan Accepted',
      'Running the AI plan through the shared JSON execution pipeline.',
      QaActivityKind.info,
    );

    final execution = _runSelectedSuite();
    _activeAiExecution = execution;
    try {
      await execution;
    } finally {
      if (identical(_activeAiExecution, execution)) {
        _activeAiExecution = null;
      }
    }
  }

  /// Opens a validated assistant plan in the existing manual workspace without
  /// launching PenguinPOS. The manual forms remain the operator's editable
  /// review surface; execution can only begin from their Run action.
  Future<void> _openAiPlanInManualMode(AiTestPlan plan) async {
    final profile = _profileForId(plan.profileId);
    if (profile.id.isEmpty) {
      _addMessage(
        'Plan Needs Attention',
        'The target profile in this plan is no longer configured.',
        QaActivityKind.error,
      );
      return;
    }
    final credentials = await _credentialVault.read(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _selectedSuiteId = plan.isOrder ? 'order_checkout' : 'login_terminal';
      if (plan.isOrder) {
        _orderScenario = OrderScenario(
          id: 'ai_${profile.id}_order_cash',
          name: 'AI planned Order & Cash Payment',
          items: plan.items,
          ordersCount: plan.ordersCount,
          inputSourceMode: InputSourceMode.uiForm,
          uiCustomMode: plan.itemStrategy == AiItemStrategy.perOrder
              ? UiCustomMode.perIteration
              : UiCustomMode.common,
          perIterationItems: plan.perIterationItems,
        );
      }
      _aiModeEnabled = false;
    });
    await _preferences.saveSelectedProfileId(profile.id);
    await _preferences.saveAiModeEnabled(false);
    _addMessage(
      'Plan Opened in Manual Mode',
      'Review and edit the generated plan before running it.',
      QaActivityKind.info,
    );
  }

  QaProfile _profileForId(String profileId) => _profiles.firstWhere(
    (candidate) => candidate.id == profileId,
    orElse: () =>
        const QaProfile(id: '', label: '', entity: '', environment: ''),
  );

  TestRunCommand _manualTestRunCommand() => TestRunCommand(
    testCaseId: _selectedSuiteId == 'order_checkout'
        ? 'order_checkout'
        : 'login_terminal',
    profileId: _profile.id,
    inputs: _selectedSuiteId == 'order_checkout'
        ? <String, Object?>{
            'ordersCount': _orderScenario.ordersCount,
            'itemStrategy':
                _orderScenario.uiCustomMode == UiCustomMode.perIteration
                ? 'perOrder'
                : 'sameForAll',
            'items': _orderScenario.items
                .map((item) => item.toJson())
                .toList(growable: false),
            if (_orderScenario.perIterationItems.isNotEmpty)
              'perOrderItems': _orderScenario.perIterationItems.entries
                  .map(
                    (entry) => <String, Object?>{
                      'order': entry.key,
                      'items': entry.value
                          .map((item) => item.toJson())
                          .toList(growable: false),
                    },
                  )
                  .toList(growable: false),
          }
        : const <String, Object?>{},
  );

  ExecutionPlan _manualExecutionPlan() =>
      const TestRunCommandMapper().map(_manualTestRunCommand());

  /// The only GUI execution entry point. Both the Manual form and AI plan
  /// handoff configure the same [ExecutionPlan], which is prepared and run by
  /// the application service rather than by this widget.
  Future<void> _runSelectedSuite({bool skipPreflight = false}) async {
    if (_running) return;
    final activeSuite = _activeSuite;
    if (!activeSuite.isImplemented) {
      _addMessage(
        'Suite Pending',
        'The ${activeSuite.title} runner is not available yet.',
        QaActivityKind.info,
      );
      return;
    }

    final plan = _manualExecutionPlan();
    final liveTraces = <ApiTraceEvent>[];
    final traceIds = <int>{};
    setState(() {
      _running = true;
      _stopRequested = false;
      _lastExecutionPassed = null;
      _lastExecutionDetails = null;
      _lastOrderRunResult = null;
      _apiTraces = const <ApiTraceEvent>[];
      _wasAppClosedByUser = false;
      _scenariosCompletedSoFar = <String>[];
      // The activity panel and the Manual-mode timeline describe this run
      // only. A previous cancellation must never appear beside a later pass.
      _messages.clear();
      _pendingMessages.clear();
      _executionSteps.clear();
      _executionSuiteTitle = activeSuite.title;
      _executionProfileLabel = _profile.label;
      _seedExecutionSteps(activeSuite);
    });
    _executionStopwatch
      ..reset()
      ..start();
    _addMessage(
      'Processing Suite',
      'Preparing ${activeSuite.title} for ${_profile.label} (${_targetMode == QaTargetMode.local ? "Local" : "SSH Remote"}).',
      QaActivityKind.info,
    );
    _addMessage(
      'Preflight Checks',
      'Validating profile, non-production safety, saved credentials, and target configuration.',
      QaActivityKind.info,
    );

    try {
      final prepared = await _executionService.prepareExecution(
        plan: plan,
        profile: _profile,
        appRoot: _appRoot,
        flutterExecutable: _flutterPath,
        targetMode: _targetMode,
        sshConfig: _sshConfig,
      );
      _addMessage(
        'Preflight Passed',
        _targetMode == QaTargetMode.ssh
            ? 'Profile and SSH target configuration are ready. Starting remote launch.'
            : 'Profile and local application configuration are ready. Starting local launch.',
        QaActivityKind.success,
      );
      final result = await _executionService.execute(
        prepared,
        callbacks: ExecutionCallbacks(
          onEvent: _recordExecutionEvent,
          onScenarioCompleted: _recordCompletedScenario,
          onOrderProgress: (completed, total) => _addMessage(
            'Order Progress',
            'Completed order $completed of $total back-to-back orders.',
            QaActivityKind.info,
          ),
          onApiTrace: (trace) {
            if (traceIds.add(trace.traceId)) {
              liveTraces.add(trace);
              _queueApiTraces(List<ApiTraceEvent>.unmodifiable(liveTraces));
            }
          },
          onTelemetryWarning: (message) =>
              _addMessage('Telemetry Warning', message, QaActivityKind.info),
        ),
      );
      _flushDashboardUpdates();
      final orderResult = result.plan.isOrder
          ? OrderRunResult(
              passed: result.passed,
              startedAt: result.startedAt,
              finishedAt: result.finishedAt,
              ordersCompleted: result.orderSummary?.ordersCompleted ?? 0,
              ordersTarget: result.orderSummary?.ordersTarget ?? 0,
              totalItemsProcessed:
                  result.orderSummary?.totalItemsProcessed ?? 0,
              aggregateTotalPayable:
                  result.orderSummary?.aggregateTotalPayable ?? 0,
              aggregatePayableAmount:
                  result.orderSummary?.aggregatePayableAmount ?? 0,
              loopMetrics: result.orderLoopMetrics,
              error: result.error,
              wasAppClosedByUser: result.wasAppClosedByUser,
              metadata: result.runnerMetadata,
            )
          : null;
      if (!mounted) return;
      setState(() {
        _lastExecutionDuration = result.duration;
        _lastExecutionPassed = result.passed;
        _wasAppClosedByUser = result.wasAppClosedByUser;
        _lastOrderRunResult = orderResult;
        _scenariosCompletedSoFar = List<String>.from(result.completedScenarios);
        _apiTraces = result.apiTraces;
        _lastExecutionDetails = result.passed
            ? (result.plan.isOrder
                  ? 'Punched ${result.orderSummary?.ordersCompleted ?? 0} orders (${result.orderSummary?.totalItemsProcessed ?? 0} total items).'
                  : 'Successfully executed: ${result.completedScenarios.join(', ')}.')
            : (result.error ?? 'The test did not reach the expected UI state.');
      });
      _addMessage(
        result.passed ? 'Suite Passed' : 'Suite Failed',
        _lastExecutionDetails!,
        result.passed ? QaActivityKind.success : QaActivityKind.error,
      );
      if (_aiModeEnabled) {
        final completed = result.completedScenarios.toSet();
        final scenarioResults = activeSuite.scenarios
            .map(
              (scenario) => AiScenarioResult(
                name: scenario.name,
                passed: completed.contains(scenario.name),
                durationMs: -1,
                detail: completed.contains(scenario.name) ? null : result.error,
              ),
            )
            .toList(growable: false);
        _aiChatMessages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            text: result.passed
                ? 'Test suite completed successfully.'
                : 'Test suite finished with failures.',
            richContent: AiRichGenUi(
              document: _buildExecutionGenUi(
                isOrder: result.plan.isOrder,
                passed: result.passed,
                durationMs: result.duration.inMilliseconds,
                scenarioResults: scenarioResults,
                orderResult: orderResult,
                cleanupPassed: result.cleanupPassed,
                wasAppClosed: result.wasAppClosedByUser,
                loginMetadata: result.runnerMetadata,
              ),
            ),
          ),
        );
      }
    } on PreflightValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _lastExecutionPassed = null;
        _lastExecutionDetails = error.message;
      });
      _addMessage('Execution Blocked', error.message, QaActivityKind.error);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastExecutionPassed = false;
        _lastExecutionDetails = error.toString();
      });
      _addMessage('Suite Error', error.toString(), QaActivityKind.error);
    } finally {
      _flushDashboardUpdates();
      _executionStopwatch.stop();
      if (mounted) {
        setState(() {
          _running = false;
          _executionSteps.clear();
        });
      }
    }
  }

  TestSuiteItem get _activeSuite => TestSuiteItem.availableSuites.firstWhere(
    (suite) => suite.id == _selectedSuiteId,
    orElse: () => TestSuiteItem.availableSuites.first,
  );

  void _seedExecutionSteps(TestSuiteItem suite) {
    for (final scenario in suite.scenarios) {
      _executionSteps.add(
        AiExecutionStep(
          scenarioName: scenario.name,
          status: AiScenarioStatus.pending,
          totalScenarios: suite.scenarios.length,
          completedScenarios: 0,
        ),
      );
    }
  }

  QaGenUiDocument _buildExecutionGenUi({
    required bool isOrder,
    required bool passed,
    required int durationMs,
    required List<AiScenarioResult> scenarioResults,
    required OrderRunResult? orderResult,
    required bool? cleanupPassed,
    required bool wasAppClosed,
    required Map<String, Object?> loginMetadata,
  }) {
    final timeline = isOrder
        ? _buildOrderTimeline(
            scenarioResults,
            orderResult: orderResult,
            traces: _apiTraces,
          )
        : _buildLoginTimeline(
            scenarioResults,
            cleanupPassed: cleanupPassed,
            wasAppClosed: wasAppClosed,
            metadata: loginMetadata,
            traces: _apiTraces,
          );
    final document = QaGenUiDocument.tryParse(<String, Object?>{
      'components': <Object?>[
        <String, Object?>{
          'component': isOrder ? 'orderPlan' : 'loginPlan',
          'title': isOrder ? 'Order execution' : 'Login & Terminal execution',
          'workflowLabel': _executionSuiteTitle,
          'profileLabel': _executionProfileLabel,
          'summary': isOrder && orderResult != null
              ? '${orderResult.ordersCompleted} of ${orderResult.ordersTarget} orders completed.'
              : 'Login, terminal selection, home verification, and logout cleanup.',
        },
        <String, Object?>{
          'component': 'stepTimeline',
          'title': 'Execution timeline',
          'steps': timeline.map(_timelineJson).toList(growable: false),
        },
        <String, Object?>{
          'component': 'resultSummary',
          'title': passed ? 'Suite passed' : 'Suite finished with failures',
          'passed': passed,
          'summary':
              'Completed in ${durationMs < 1000 ? '${durationMs}ms' : '${(durationMs / 1000).toStringAsFixed(1)}s'}.',
        },
      ],
    });
    return document!;
  }

  Map<String, Object?> _timelineJson(
    AiScenarioResult result,
  ) => <String, Object?>{
    'label': result.name,
    'status': result.detail?.startsWith('__pending__') == true
        ? 'pending'
        : result.detail?.startsWith('__skipped__') == true
        ? 'skipped'
        : (result.passed ? 'passed' : 'failed'),
    if (result.durationMs >= 0) 'durationMs': result.durationMs,
    if (result.detail != null &&
        !result.detail!.startsWith('__pending__') &&
        !result.detail!.startsWith('__skipped__'))
      'detail': result.detail,
    if (result.detail?.startsWith('__skipped__: ') == true)
      'detail': result.detail!.substring('__skipped__: '.length),
    if (result.children.isNotEmpty)
      'children': result.children.map(_timelineJson).toList(growable: false),
  };

  List<AiScenarioResult> _buildOrderTimeline(
    List<AiScenarioResult> scenarioResults, {
    required OrderRunResult? orderResult,
    required List<ApiTraceEvent> traces,
  }) {
    AiScenarioResult stage(
      String name,
      bool passed, {
      String? detail,
      List<AiScenarioResult> children = const <AiScenarioResult>[],
    }) => AiScenarioResult(
      name: name,
      passed: passed,
      durationMs: -1,
      detail: detail,
      children: children,
    );

    AiScenarioResult api(ApiTraceEvent trace) => AiScenarioResult(
      name: '${trace.method} ${trace.route}',
      passed: trace.result.name == 'success',
      durationMs: trace.durationMs,
      detail:
          '${trace.statusCode ?? '-'} · ${trace.mode.name == 'unknown' ? 'target' : trace.mode.name}',
    );

    final initialScreen = orderResult?.metadata['initial_screen'];
    final loggedIn =
        orderResult?.metadata['initial_session_state'] == 'logged_in';
    final loginApis = traces
        .where(
          (trace) =>
              trace.route.toLowerCase().contains('/login') ||
              trace.route.toLowerCase().contains('terminal-selection'),
        )
        .map(api)
        .toList(growable: false);
    final splashApis = traces
        .where(
          (trace) =>
              trace.route.toLowerCase().contains('device-config') ||
              trace.route.toLowerCase().contains('terminal-events'),
        )
        .map(api)
        .toList(growable: false);
    final orderSteps = <AiScenarioResult>[];
    final metrics = orderResult?.loopMetrics ?? const <OrderLoopMetrics>[];
    for (final metric in metrics) {
      final children = metric.stepMetrics
          .map(
            (step) => AiScenarioResult(
              name: step.stepName,
              passed: true,
              durationMs: step.uiRenderTimeMs,
              detail: step.apiTelemetry == null
                  ? null
                  : '${step.apiTelemetry!.statusCode} · API ${step.apiTelemetry!.responseTimeMs}ms',
            ),
          )
          .toList(growable: false);
      orderSteps.add(
        stage(
          'Order ${metric.loopIndex}',
          true,
          detail: '${metric.itemsCount} items · ₹${metric.payableCash} cash',
          children: children,
        ),
      );
    }
    if (orderSteps.isEmpty) {
      orderSteps.addAll(
        scenarioResults.map(
          (result) => stage(result.name, result.passed, detail: result.detail),
        ),
      );
    }

    return <AiScenarioResult>[
      stage(
        'Splash Screen',
        splashApis.isNotEmpty && splashApis.every((item) => item.passed),
        children: splashApis,
      ),
      stage(
        'Check If Logged In',
        orderResult?.metadata.isNotEmpty == true,
        detail: loggedIn
            ? 'Already logged in on ${initialScreen ?? 'authenticated screen'} — login and terminal selection skipped.'
            : 'Login screen detected — login and terminal selection required.',
      ),
      if (!loggedIn)
        stage(
          'Login',
          loginApis
              .where((item) => item.name.contains('/login'))
              .every((item) => item.passed),
          children: loginApis
              .where((item) => item.name.contains('/login'))
              .toList(growable: false),
        ),
      if (!loggedIn)
        stage(
          'Terminal Selection',
          loginApis
              .where((item) => item.name.contains('terminal-selection'))
              .every((item) => item.passed),
          children: loginApis
              .where((item) => item.name.contains('terminal-selection'))
              .toList(growable: false),
        ),
      stage(
        'Continue With Order',
        orderSteps.every((item) => item.passed),
        children: orderSteps,
      ),
    ];
  }

  List<AiScenarioResult> _buildLoginTimeline(
    List<AiScenarioResult> scenarioResults, {
    required bool? cleanupPassed,
    required bool wasAppClosed,
    required Map<String, Object?> metadata,
    required List<ApiTraceEvent> traces,
  }) {
    AiScenarioResult status(
      String name,
      bool passed, {
      bool observed = true,
      String? detail,
      List<AiScenarioResult> children = const <AiScenarioResult>[],
    }) => AiScenarioResult(
      name: name,
      passed: passed,
      // Stage/decision rows are labels, not timed API calls. Durations are
      // attached only to the concrete API rows below them in the flat chain.
      durationMs: -1,
      detail: detail ?? (observed ? null : '__pending__'),
      children: children,
    );
    final completed = _scenariosCompletedSoFar.toSet();
    final failure = scenarioResults
        .where((item) => !item.passed && item.detail != null)
        .map((item) => item.detail!)
        .firstOrNull;
    List<AiScenarioResult> apiRows(String category) {
      final selected = traces.where((trace) {
        final route = trace.route.toLowerCase();
        return switch (category) {
          'splash' => route.contains('splash'),
          'device_config' =>
            route.contains('device-config') && !route.contains('/modes'),
          'device_modes' =>
            route.contains('device-config') && route.contains('/modes'),
          'terminal' => route.contains('terminal-events'),
          'auth' =>
            route.contains('/login') ||
                route.contains('/logout') ||
                route.contains('terminal-selection'),
          _ => false,
        };
      });
      return selected
          .map(
            (trace) => AiScenarioResult(
              name: '${trace.method} ${trace.route}',
              passed: trace.result.name == 'success',
              durationMs: trace.durationMs,
              detail:
                  '${trace.statusCode ?? '-'} · ${trace.mode.name == 'unknown' ? 'target' : trace.mode.name}',
            ),
          )
          .toList(growable: false);
    }

    final initialState = metadata['initial_session_state'];
    final splashApis = <AiScenarioResult>[
      ...apiRows('device_config'),
      ...apiRows('device_modes'),
      ...apiRows('terminal'),
    ];
    final logoutApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('/logout'))
        .toList(growable: false);
    final initialLogout = initialState == 'logged_in' && logoutApis.isNotEmpty
        ? <AiScenarioResult>[logoutApis.first]
        : const <AiScenarioResult>[];
    final finalLogout = logoutApis.length > 1
        ? <AiScenarioResult>[logoutApis.last]
        : (initialState == 'logged_out' && logoutApis.isNotEmpty
              ? <AiScenarioResult>[logoutApis.last]
              : const <AiScenarioResult>[]);
    final loginApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('/login'))
        .toList(growable: false);
    final terminalSelectionApis = apiRows('auth')
        .where((item) => item.name.toLowerCase().contains('terminal-selection'))
        .toList(growable: false);

    return <AiScenarioResult>[
      status(
        'Splash Screen',
        splashApis.isNotEmpty && splashApis.every((step) => step.passed),
        observed: splashApis.isNotEmpty,
        children: splashApis,
      ),
      status(
        'Check If Logged In',
        initialState != null,
        observed: initialState != null || wasAppClosed,
        detail: initialState == 'logged_out'
            ? '__skipped__: Already logged out — no logout API required.'
            : (initialState == 'logged_in'
                  ? 'Existing session detected — initial logout required.'
                  : (wasAppClosed
                        ? 'PenguinPOS was quit before the initial logout.'
                        : null)),
        children: initialLogout.isEmpty
            ? const <AiScenarioResult>[]
            : <AiScenarioResult>[
                status(
                  'Logging Out User',
                  initialLogout.every((step) => step.passed),
                  children: initialLogout,
                ),
              ],
      ),
      status(
        'Login',
        completed.contains('Valid Login Flow') ||
            traces.any(
              (trace) =>
                  trace.route.contains('/login') && trace.statusCode == 201,
            ),
        detail: failure,
        children: loginApis,
      ),
      status(
        'Terminal Selection',
        completed.contains('Select Terminal') ||
            terminalSelectionApis.isNotEmpty,
        observed:
            completed.contains('Select Terminal') ||
            terminalSelectionApis.isNotEmpty,
        detail: failure,
        children: terminalSelectionApis,
      ),
      status(
        'Logout',
        cleanupPassed == true,
        observed: cleanupPassed != null || wasAppClosed,
        detail: cleanupPassed == true
            ? null
            : (wasAppClosed
                  ? 'PenguinPOS was quit before logout.'
                  : 'Logout was not completed.'),
        children: finalLogout,
      ),
    ];
  }

  void _addMessage(String title, String body, QaActivityKind kind) {
    _pendingMessages.add(QaActivityMessage(title, body, kind));
    _scheduleDashboardUpdate();
  }

  @override
  void dispose() {
    _dashboardUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_preferencesLoaded) {
      return _buildLoadingScreen();
    }

    return Stack(
      children: <Widget>[
        ExcludeSemantics(
          excluding: _showSettingsScreen,
          child: IgnorePointer(
            ignoring: _showSettingsScreen,
            child: Scaffold(
              backgroundColor: _aiModeEnabled
                  ? const Color(0xFFFCFCFD)
                  : const Color(0xFFF1F5F9),
              body: _aiModeEnabled
                  ? _buildAssistantWorkspace()
                  : _buildManualMode(),
            ),
          ),
        ),
        if (_showSettingsScreen)
          Positioned.fill(
            child: FocusScope(
              autofocus: true,
              child: FocusTraversalGroup(child: _buildSettingsScreen()),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingScreen() => const Scaffold(
    backgroundColor: Color(0xFFFCFCFD),
    body: Center(
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );

  Widget _buildSettingsScreen() => QaSettingsScreen(
    profiles: _profiles,
    activeProfile: _profile,
    aiModelConfig: _aiModelConfig,
    noticeDisplayMode: _noticeDisplayMode,
    flutterPath: _flutterPath,
    appRoot: _appRoot,
    targetMode: _targetMode,
    sshConfig: _sshConfig,
    onProfileSelected: _selectProfile,
    onProfilesUpdated: (profiles) => setState(() => _profiles = profiles),
    onAiModelConfigUpdated: (config) {
      setState(() {
        _aiModelConfig = config;
        _aiModelConnected = false;
      });
      unawaited(_refreshAiModelConnection(config));
    },
    onNoticeDisplayModeUpdated: (mode) {
      setState(() => _noticeDisplayMode = mode);
      unawaited(_preferences.saveNoticeDisplayMode(mode));
    },
    onTargetModeUpdated: (mode) {
      setState(() => _targetMode = mode);
      unawaited(_preferences.saveTargetMode(_profile.id, mode));
    },
    onSshConfigUpdated: (config) {
      setState(() => _sshConfig = config);
      unawaited(_preferences.saveSshConfig(_profile.id, config));
    },
    onClose: () {
      setState(() => _showSettingsScreen = false);
      unawaited(_loadSavedTargetPreferences());
    },
  );

  Widget _buildAssistantWorkspace() => AiAssistantWorkspace(
    modelConfigured: _aiModelConnected,
    running: _running,
    messages: _aiChatMessages,
    onAddMessage: (msg) {
      if (mounted) {
        setState(() => _aiChatMessages.add(msg));
      }
    },
    onTruncateMessages: (index) {
      if (mounted && index >= 0 && index < _aiChatMessages.length) {
        setState(
          () => _aiChatMessages.removeRange(index, _aiChatMessages.length),
        );
      }
    },
    onPlanningStateChanged: (waiting) {
      if (mounted) {
        setState(() => _aiPlanningWaiting = waiting);
      }
    },
    activityMessages: _messages,
    apiTraces: _apiTraces,
    executionSteps: _executionSteps,
    executionSuiteTitle: _executionSuiteTitle,
    executionProfileLabel: _executionProfileLabel,
    onSend: _respondToAi,
    onRunPlan: _runAiPlan,
    onOpenPlanInManualMode: _openAiPlanInManualMode,
    onOpenSettings: _openSettingsDialog,
    onExitAiMode: () => _setAiModeEnabled(false),
  );

  Widget _buildManualMode() => Row(
    children: <Widget>[
      SideNav(
        suites: TestSuiteItem.availableSuites,
        selectedSuiteId: _selectedSuiteId,
        onSelectSuite: _selectSuite,
        onNewSuite: _showCustomSuiteBuilderNotice,
        onOpenSettings: _openSettingsDialog,
        onOpenSupport: _openSupportDialog,
        activeProfileLabel: _profile.label,
        targetMode: _targetMode,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: _buildManualModeToolbar(),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildSuiteWorkspace()),
            ],
          ),
        ),
      ),
      SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
          child: Column(
            children: <Widget>[
              Expanded(child: QaActivityPanel(messages: _messages)),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: ApiActivityPanel(
                  traces: _apiTraces,
                  onClearTraces: () =>
                      setState(() => _apiTraces = const <ApiTraceEvent>[]),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildManualModeToolbar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          'Environment:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 170, child: _buildProfileSelector()),
        const SizedBox(width: 12),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF475569),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          onPressed: _openSettingsDialog,
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: const Text(
            'Settings',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        const VerticalDivider(
          width: 1,
          indent: 4,
          endIndent: 4,
          color: Color(0xFFE2E8F0),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Local',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _targetMode == QaTargetMode.local
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            Switch.adaptive(
              value: _targetMode == QaTargetMode.ssh,
              onChanged: _running
                  ? null
                  : (isSsh) {
                      final newMode = isSsh
                          ? QaTargetMode.ssh
                          : QaTargetMode.local;
                      setState(() => _targetMode = newMode);
                      unawaited(_preferences.saveTargetMode(newMode));
                    },
            ),
            const SizedBox(width: 4),
            Text(
              'SSH',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _targetMode == QaTargetMode.ssh
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        const VerticalDivider(
          width: 1,
          indent: 4,
          endIndent: 4,
          color: Color(0xFFE2E8F0),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Manual',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Switch.adaptive(
              value: false,
              onChanged: _running ? null : _setAiModeEnabled,
            ),
            const SizedBox(width: 4),
            const Text(
              'AI',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildProfileSelector() => DropdownButtonFormField<QaProfile>(
    initialValue: _profile,
    isDense: true,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    ),
    items: _profiles
        .map(
          (profile) => DropdownMenuItem<QaProfile>(
            value: profile,
            child: Text(profile.label, style: const TextStyle(fontSize: 12.5)),
          ),
        )
        .toList(),
    onChanged: _running
        ? null
        : (profile) {
            if (profile != null) _selectProfile(profile);
          },
  );

  Widget _buildSuiteWorkspace() {
    final suite = _activeSuite;
    if (_selectedSuiteId == 'order_checkout') {
      return OrderSuiteScreen(
        suite: suite,
        currentProfile: _profile,
        targetMode: _targetMode,
        flutterPath: _flutterPath,
        appRoot: _appRoot,
        running: _running,
        lastExecutionPassed: _lastExecutionPassed,
        lastExecutionDuration: _lastExecutionDuration,
        lastExecutionDetails: _lastExecutionDetails,
        wasAppClosedByUser: _wasAppClosedByUser,
        scenariosCompleted: _scenariosCompletedSoFar,
        liveMessages: List<QaActivityMessage>.unmodifiable(_messages),
        orderScenario: _orderScenario,
        lastOrderRunResult: _lastOrderRunResult,
        onUpdateScenario: (scenario) =>
            setState(() => _orderScenario = scenario),
        onRunSuite: _runSelectedSuite,
        onStopSuite: _stopRunningSuite,
      );
    }
    return LoginSuiteScreen(
      suite: suite,
      currentProfile: _profile,
      loginId: _loginId,
      password: _password,
      targetMode: _targetMode,
      flutterPath: _flutterPath,
      appRoot: _appRoot,
      running: _running,
      lastExecutionPassed: _lastExecutionPassed,
      lastExecutionDuration: _lastExecutionDuration,
      lastExecutionDetails: _lastExecutionDetails,
      wasAppClosedByUser: _wasAppClosedByUser,
      scenariosCompleted: _scenariosCompletedSoFar,
      liveMessages: List<QaActivityMessage>.unmodifiable(_messages),
      onLoginIdChanged: (loginId) => setState(() => _loginId = loginId),
      onPasswordChanged: (password) => setState(() => _password = password),
      onRunSuite: _runSelectedSuite,
      onStopSuite: _stopRunningSuite,
    );
  }

  void _selectSuite(String suiteId) {
    setState(() {
      _selectedSuiteId = suiteId;
      _lastExecutionPassed = null;
      _wasAppClosedByUser = false;
      _lastExecutionDetails = null;
      _scenariosCompletedSoFar = <String>[];
    });
  }

  void _showCustomSuiteBuilderNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom suite builder is planned for upcoming release.'),
      ),
    );
  }
}
