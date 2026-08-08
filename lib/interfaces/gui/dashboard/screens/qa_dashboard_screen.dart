import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/providers/openai_compatible_provider.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_activity_panel.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/side_nav.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/login/login_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/order_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/ai_assistant_workspace.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/qa_settings_screen.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';

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

  bool _preferencesLoaded = false;
  bool _showFirstRunSetupPrompt = false;
  bool _showSettingsScreen = false;

  final QaTargetMode _targetMode = QaTargetMode.local;
  String _flutterPath = 'flutter';
  String _appRoot = '/Users/reddygona/Documents/PenguinPOS/penguin_pos';
  List<QaProfile> _profiles = QaProfile.values;
  QaProfile _profile = QaProfile.values.first;
  String _loginId = '';
  String _password = '';
  String _unlockPin = '';
  String _sshUser = '';
  String _sshHost = '';

  String _selectedSuiteId = 'login_terminal';
  OrderScenario _orderScenario = OrderScenario.sampleScenario;
  bool _aiModeEnabled = true;
  final List<AiChatMessage> _aiChatMessages = <AiChatMessage>[];
  AiPendingRequest? _pendingAssistantRequest;
  bool _aiPlanningWaiting = false;
  PlanningRequestHandle? _activePlanningHandle;

  bool get _hasActiveWork => _running || _aiPlanningWaiting;
  AiModelConfig _aiModelConfig = const AiModelConfig();

  bool _running = false;
  bool _stopRequested = false;
  LaunchedPenguinPos? _activeLaunch;
  Duration? _lastExecutionDuration;
  bool? _lastExecutionPassed;
  String? _lastExecutionDetails;
  bool _wasAppClosedByUser = false;
  List<String> _scenariosCompletedSoFar = <String>[];
  OrderRunResult? _lastOrderRunResult;
  bool? _lastLoginCleanupPassed;
  String? _lastLoginCleanupDetail;

  // Layer 3: Live execution progress tracking for the AI workspace.
  final _executionSteps = <AiExecutionStep>[];
  String _executionSuiteTitle = '';
  String _executionProfileLabel = '';
  final _executionStopwatch = Stopwatch();
  final GlobalKey<_AiAssistantWorkspaceHostState> _workspaceKey =
      GlobalKey<_AiAssistantWorkspaceHostState>();

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
    final target = await _preferences.loadSshTarget();
    final profiles = await _preferences.loadProfiles();
    final selectedProfileId = await _preferences.loadSelectedProfileId();
    var hasCompletedInitialSetup = await _preferences
        .hasCompletedInitialSetup();
    final aiModelConfig = await _preferences.loadAiModelConfig();
    final selectedProfile = profiles.firstWhere(
      (profile) => profile.id == selectedProfileId,
      orElse: () => profiles.first,
    );
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
      _sshUser = target.username;
      _sshHost = target.host;
      _profiles = profiles;
      _profile = selectedProfile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
      _aiModelConfig = aiModelConfig;
      _preferencesLoaded = true;
      _showFirstRunSetupPrompt = !hasCompletedInitialSetup;
    });
    if (!hasCompletedInitialSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showFirstRunSetupPrompt) {
          _openFirstRunSetupDialog();
        }
      });
    }
    _refreshDetectedPaths();
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
      _unlockPin = credentials.unlockPin;
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
      _stopActiveWork();
    }
    setState(() => _aiModeEnabled = enabled);
    await _preferences.saveAiModeEnabled(enabled);
  }

  void _stopActiveWork() {
    _activePlanningHandle?.cancel();
    _activePlanningHandle = null;
    if (_running) {
      _stopRunningSuite();
    }
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
    await _activeLaunch?.close();
  }

  void _recordCompletedScenario(String scenarioName) {
    if (!mounted) return;
    setState(() {
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
    });
  }

  void _recordExecutionEvent(ExecutionEvent event) {
    _addMessage(event.title, event.message, switch (event.level) {
      ExecutionEventLevel.success => QaActivityKind.success,
      ExecutionEventLevel.error => QaActivityKind.error,
      ExecutionEventLevel.info => QaActivityKind.info,
    });

    // Update detail message on an existing matching scenario step if visible
    if (mounted) {
      final idx = _executionSteps.indexWhere(
        (s) => s.scenarioName == event.title,
      );
      if (idx >= 0 && _executionSteps[idx].status == AiScenarioStatus.pending) {
        setState(() {
          _executionSteps[idx] = AiExecutionStep(
            scenarioName: event.title,
            status: AiScenarioStatus.running,
            detail: event.message,
            totalScenarios: _executionSteps[idx].totalScenarios,
            completedScenarios: _scenariosCompletedSoFar.length,
          );
        });
      }
    }
  }

  String _interruptionDetails({required bool wasStopped}) => wasStopped
      ? 'Test stopped by the user. Completed test cases are retained; remaining cases are pending.'
      : 'PenguinPOS was quit during testing. Completed test cases are retained; remaining cases are pending.';

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

  Future<void> _runAiPlan(AiTestPlan plan) async {
    final profile = _profileForId(plan.profileId);
    final plannedSuite = plan.isOrder
        ? _suiteForId('order_checkout')
        : _suiteForId('login_terminal');
    final preflightSteps = <String>[
      'Matched target profile: ${profile.label.isEmpty ? plan.profileId : profile.label}',
      'Confirmed approved non-production target',
      'Checked saved credentials',
      'Checked ${plannedSuite.title} readiness',
      'Confirmed local launch is available',
    ];
    _startAiPreflight(
      profileLabel: profile.label.isEmpty ? plan.profileId : profile.label,
      steps: preflightSteps,
    );

    if (profile.id.isEmpty) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 0,
        message:
            'I could not find the selected target profile. Choose an approved non-production profile and try again.',
      );
      _addMessage(
        'Execution Blocked',
        'The selected target profile is no longer configured. Choose an approved non-production profile and try again.',
        QaActivityKind.error,
      );
      return;
    }
    _updateAiPreflightStep(0, AiScenarioStatus.passed);
    if (profile.isProduction) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 1,
        message:
            'Production environments are strictly prohibited. No application was launched.',
      );
      _addMessage(
        'Execution Blocked',
        'Production environments are strictly prohibited for QA Agent execution.',
        QaActivityKind.error,
      );
      return;
    }
    _updateAiPreflightStep(1, AiScenarioStatus.passed);
    final credentials = await _credentialVault.read(profile.id);
    if (credentials.loginId.isEmpty || credentials.password.isEmpty) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 2,
        message:
            'Credentials are missing for ${profile.label}. Open Settings → Credentials, select this profile, and save the login ID and password.',
      );
      _addMessage(
        'Credentials Required',
        'Save the login ID and password for ${profile.label} in Settings → Credentials before running this plan.',
        QaActivityKind.error,
      );
      return;
    }
    _updateAiPreflightStep(2, AiScenarioStatus.passed);

    if (!plannedSuite.isImplemented) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 3,
        message:
            '${plannedSuite.title} is configured but does not yet have an executable runner.',
      );
      _addMessage(
        'Suite Pending',
        'The ${plannedSuite.title} runner is scheduled for the next phase.',
        QaActivityKind.info,
      );
      return;
    }
    _updateAiPreflightStep(3, AiScenarioStatus.passed);

    if (_targetMode == QaTargetMode.ssh) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 4,
        message:
            'SSH execution is not available yet. No application was launched.',
      );
      _addMessage(
        'SSH Execution Pending',
        'Target $_sshUser@$_sshHost saved. SSH remote runner is planned for next phase.',
        QaActivityKind.info,
      );
      return;
    }

    final appRootIsValid = await PathDetector.isValidAppRoot(_appRoot);
    final flutterIsValid = await PathDetector.isValidFlutterExecutable(
      _flutterPath,
    );
    if (!appRootIsValid || !flutterIsValid) {
      _finishAiPreflight(
        steps: preflightSteps,
        failedStep: 4,
        message:
            'The local PenguinPOS app path or Flutter executable is not ready. Review Settings → System & Engine Paths before running.',
      );
      _addMessage(
        'Launch Setup Required',
        'Review the PenguinPOS app root and Flutter executable in Settings → System & Engine Paths before running this plan.',
        QaActivityKind.error,
      );
      return;
    }
    _updateAiPreflightStep(4, AiScenarioStatus.passed);

    setState(() {
      _profile = profile;
      _loginId = credentials.loginId;
      _password = credentials.password;
      _unlockPin = credentials.unlockPin;
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
    _finishAiPreflight(
      steps: preflightSteps,
      message:
          'Preflight passed for ${profile.label}. Launching ${plannedSuite.title}…',
    );
    await _runSelectedSuite();
  }

  QaProfile _profileForId(String profileId) => _profiles.firstWhere(
    (candidate) => candidate.id == profileId,
    orElse: () =>
        const QaProfile(id: '', label: '', entity: '', environment: ''),
  );

  TestSuiteItem _suiteForId(String suiteId) =>
      TestSuiteItem.availableSuites.firstWhere(
        (suite) => suite.id == suiteId,
        orElse: () => TestSuiteItem.availableSuites.first,
      );

  /// Emits a user-safe preflight timeline before an AI plan can launch the
  /// target app. This is application activity, not private model reasoning.
  void _startAiPreflight({
    required String profileLabel,
    required List<String> steps,
  }) {
    setState(() {
      _running = true;
      _executionSuiteTitle = 'Preflight checks';
      _executionProfileLabel = profileLabel;
      _executionSteps
        ..clear()
        ..addAll(
          List<AiExecutionStep>.generate(
            steps.length,
            (index) => AiExecutionStep(
              scenarioName: steps[index],
              status: index == 0
                  ? AiScenarioStatus.running
                  : AiScenarioStatus.pending,
              totalScenarios: steps.length,
              completedScenarios: 0,
            ),
          ),
        );
    });
  }

  void _updateAiPreflightStep(int index, AiScenarioStatus status) {
    if (index < 0 || index >= _executionSteps.length) return;
    setState(() {
      final previous = _executionSteps[index];
      _executionSteps[index] = AiExecutionStep(
        scenarioName: previous.scenarioName,
        status: status,
        totalScenarios: previous.totalScenarios,
        completedScenarios: status == AiScenarioStatus.passed
            ? index + 1
            : index,
      );
      if (status == AiScenarioStatus.passed &&
          index + 1 < _executionSteps.length) {
        final next = _executionSteps[index + 1];
        _executionSteps[index + 1] = AiExecutionStep(
          scenarioName: next.scenarioName,
          status: AiScenarioStatus.running,
          totalScenarios: next.totalScenarios,
          completedScenarios: index + 1,
        );
      }
    });
  }

  void _finishAiPreflight({
    required List<String> steps,
    required String message,
    int? failedStep,
  }) {
    if (failedStep != null) {
      _updateAiPreflightStep(failedStep, AiScenarioStatus.failed);
    }
    if (_aiModeEnabled) {
      setState(() {
        _aiChatMessages.add(
          AiChatMessage(
            role: AiChatRole.assistant,
            text: message,
            richContent: AiRichPlanningSummary(
              steps: steps,
              failedStep: failedStep,
            ),
          ),
        );
      });
    }
    setState(() {
      _running = false;
      _executionSteps.clear();
    });
  }

  Future<void> _runSelectedSuite() async {
    // Keep this check at the execution boundary. AI planning and manual mode
    // share this runner, so neither path can execute a production profile.
    if (_profile.isProduction) {
      _addMessage(
        'Execution Blocked',
        'Production environments are strictly prohibited for QA Agent execution.',
        QaActivityKind.error,
      );
      return;
    }
    final currentSuite = _activeSuite;

    if (!currentSuite.isImplemented) {
      _addMessage(
        'Suite Pending',
        'The ${currentSuite.title} runner is scheduled for the next phase.',
        QaActivityKind.info,
      );
      setState(() {
        _lastExecutionPassed = null;
        _wasAppClosedByUser = false;
        _lastExecutionDetails =
            'This test suite is currently planned for the upcoming release phase.';
      });
      return;
    }

    if (_targetMode == QaTargetMode.ssh) {
      _addMessage(
        'SSH Execution Pending',
        'Target $_sshUser@$_sshHost saved. SSH remote runner is planned for next phase.',
        QaActivityKind.info,
      );
      setState(() {
        _lastExecutionPassed = null;
        _wasAppClosedByUser = false;
        _lastExecutionDetails =
            'SSH execution target configured, but remote executor is intentionally deferred to the SSH phase.';
      });
      return;
    }

    final activeSuite = _activeSuite;

    setState(() {
      _running = true;
      _lastExecutionPassed = null;
      _lastExecutionDetails = null;
      _lastLoginCleanupPassed = null;
      _lastLoginCleanupDetail = null;
      _wasAppClosedByUser = false;
      _stopRequested = false;
      _scenariosCompletedSoFar = <String>[];
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
      'Launching PenguinPOS via $_flutterPath at $_appRoot for ${_profile.label}...',
      QaActivityKind.info,
    );

    LaunchedPenguinPos? launched;
    final stopwatch = Stopwatch()..start();

    try {
      launched = await PenguinPosAppLauncher().launch(
        appRoot: _appRoot,
        flutterExecutable: _flutterPath,
        entity: _profile.entity,
        env: _profile.environment,
      );
      _activeLaunch = launched;

      if (_stopRequested) {
        stopwatch.stop();
        setState(() {
          _lastExecutionDuration = stopwatch.elapsed;
          _lastExecutionPassed = false;
          _wasAppClosedByUser = true;
          _lastExecutionDetails = _interruptionDetails(wasStopped: true);
        });
        _addMessage(
          'Test Stopped',
          _lastExecutionDetails!,
          QaActivityKind.info,
        );
        return;
      }

      if (_selectedSuiteId == 'order_checkout') {
        final scenario = OrderScenario(
          id: _orderScenario.id,
          name: _orderScenario.name,
          loginId: _loginId.isNotEmpty ? _loginId : null,
          password: _password.isNotEmpty ? _password : null,
          unlockPin: _unlockPin.isNotEmpty ? _unlockPin : null,
          items: _orderScenario.items,
          ordersCount: _orderScenario.ordersCount,
          inputSourceMode: _orderScenario.inputSourceMode,
          uiCustomMode: _orderScenario.uiCustomMode,
          perIterationItems: _orderScenario.perIterationItems,
          rawJson: _orderScenario.rawJson,
          rawCsv: _orderScenario.rawCsv,
        );

        final result = await PenguinPosOrderRunner().run(
          scenario,
          vmServiceUri: launched.vmServiceUri,
          onScenarioCompleted: _recordCompletedScenario,
          onBatchProgress: (completed, total) {
            _addMessage(
              'Order Progress',
              'Completed order $completed of $total back-to-back orders.',
              QaActivityKind.info,
            );
          },
          onExecutionEvent: _recordExecutionEvent,
        );

        stopwatch.stop();

        setState(() {
          _lastOrderRunResult = result;
          _lastExecutionDuration = stopwatch.elapsed;
          _lastExecutionPassed = result.passed;
          _wasAppClosedByUser = result.wasAppClosedByUser || _stopRequested;
          if (result.passed) {
            _scenariosCompletedSoFar = <String>[
              'Start Sale & Customer Handling',
              'SKU & Weighed Item Entry',
              'Cash Payment & Round-Off',
            ];
          }
          _lastExecutionDetails = result.passed
              ? 'Punched ${result.ordersCompleted} orders (${result.totalItemsProcessed} total items). Aggregate payable: ₹${result.aggregateTotalPayable.toStringAsFixed(2)} → Cash: ₹${result.aggregatePayableAmount}.'
              : (_wasAppClosedByUser
                    ? _interruptionDetails(wasStopped: _stopRequested)
                    : (result.error ??
                          'The test driver did not reach the expected UI state.'));
        });

        if (_wasAppClosedByUser) {
          _addMessage(
            _stopRequested ? 'Test Stopped' : 'Application Quit',
            _lastExecutionDetails!,
            QaActivityKind.info,
          );
        } else {
          _addMessage(
            result.passed ? 'Order Suite Passed 🎉' : 'Order Suite Failed ❌',
            result.passed
                ? 'Punched ${result.ordersCompleted} of ${result.ordersTarget} orders (${result.totalItemsProcessed} items) in ${stopwatch.elapsed.inSeconds}s (Cash: ₹${result.aggregatePayableAmount}).'
                : (result.error ?? 'Order checkout test failed.'),
            result.passed ? QaActivityKind.success : QaActivityKind.error,
          );
        }
      } else {
        final result = await PenguinPosLoginRunner().runFullSequence(
          LoginScenario(
            id: 'login_terminal_full_sequence',
            name: 'Login and terminal selection',
            loginId: _loginId,
            password: _password,
            unlockPin: _unlockPin,
          ),
          vmServiceUri: launched.vmServiceUri,
          onExecutionEvent: _recordExecutionEvent,
          onScenarioCompleted: _recordCompletedScenario,
        );

        stopwatch.stop();

        setState(() {
          _lastExecutionDuration = stopwatch.elapsed;
          _lastExecutionPassed = result.passed;
          _lastLoginCleanupPassed = result.cleanupPassed;
          _lastLoginCleanupDetail = result.cleanupDetail;
          _wasAppClosedByUser = result.wasAppClosedByUser || _stopRequested;
          _scenariosCompletedSoFar = result.scenariosExecuted;
          _lastExecutionDetails = result.passed
              ? 'Successfully executed all scenarios: ${result.scenariosExecuted.join(', ')}.${result.cleanupPassed == false ? ' Cleanup failed; session isolation is not guaranteed.' : ''}'
              : (_wasAppClosedByUser
                    ? _interruptionDetails(wasStopped: _stopRequested)
                    : (result.error ??
                          'The test driver did not reach the expected UI state.'));
        });

        if (_wasAppClosedByUser) {
          _addMessage(
            _stopRequested ? 'Test Stopped' : 'Application Quit',
            _lastExecutionDetails!,
            QaActivityKind.info,
          );
        } else {
          _addMessage(
            result.passed ? 'Suite Passed 🎉' : 'Suite Failed ❌',
            result.passed
                ? 'Completed in ${stopwatch.elapsed.inSeconds}s (${result.scenariosExecuted.length} scenarios).${result.cleanupPassed == false ? ' Cleanup failed; session isolation is not guaranteed.' : ''}'
                : (result.error ?? 'Test execution failed.'),
            result.passed ? QaActivityKind.success : QaActivityKind.error,
          );
        }
      }
    } catch (error) {
      stopwatch.stop();
      final errStr = error.toString();
      final isAppQuit =
          errStr.contains('Service has disappeared') ||
          errStr.contains('112') ||
          errStr.contains('SocketException') ||
          errStr.contains('Closed');

      setState(() {
        _lastExecutionDuration = stopwatch.elapsed;
        _lastExecutionPassed = false;
        _wasAppClosedByUser = isAppQuit || _stopRequested;
        _lastExecutionDetails = (isAppQuit || _stopRequested)
            ? _interruptionDetails(wasStopped: _stopRequested)
            : errStr;
      });

      if (isAppQuit || _stopRequested) {
        _addMessage(
          _stopRequested ? 'Test Stopped' : 'Application Quit',
          _lastExecutionDetails!,
          QaActivityKind.info,
        );
      } else {
        _addMessage('Suite Error', errStr, QaActivityKind.error);
      }
    } finally {
      try {
        await launched?.close();
      } catch (_) {}
      if (identical(_activeLaunch, launched)) _activeLaunch = null;
      _executionStopwatch.stop();
      if (mounted) {
        setState(() {
          _running = false;
        });

        // Layer 3: Auto-inject a rich test report message into the chat
        if (_aiModeEnabled && _lastExecutionPassed != null) {
          final scenarioResults = <AiScenarioResult>[];
          final suiteScenarios = activeSuite.scenarios;
          for (final scenario in suiteScenarios) {
            final passed = _scenariosCompletedSoFar.contains(scenario.name);
            scenarioResults.add(
              AiScenarioResult(
                name: scenario.name,
                passed: passed,
                durationMs: passed
                    ? (stopwatch.elapsedMilliseconds ~/ suiteScenarios.length)
                    : 0,
              ),
            );
          }

          final AiRichContent reportContent;
          final orderResult = _lastOrderRunResult;
          if (_selectedSuiteId == 'order_checkout' && orderResult != null) {
            reportContent = AiRichOrderReport(
              suiteTitle: _executionSuiteTitle,
              profileLabel: _executionProfileLabel,
              passed: _lastExecutionPassed!,
              totalDurationMs: stopwatch.elapsedMilliseconds,
              orders: _buildAiOrderResults(orderResult),
              testChecks: scenarioResults,
            );
          } else {
            reportContent = AiRichTestReport(
              suiteTitle: _executionSuiteTitle,
              profileLabel: _executionProfileLabel,
              passed: _lastExecutionPassed!,
              totalDurationMs: stopwatch.elapsedMilliseconds,
              scenarioResults: scenarioResults,
              cleanupPassed: _lastLoginCleanupPassed,
              cleanupDetail: _lastLoginCleanupDetail,
            );
          }

          final reportMessage = AiChatMessage(
            role: AiChatRole.assistant,
            text: _lastExecutionPassed!
                ? 'Test suite completed successfully.'
                : 'Test suite finished with failures.',
            richContent: reportContent,
          );
          setState(() {
            _aiChatMessages.add(reportMessage);
          });
        }

        // Clear temporary execution steps so floating tracker box disappears
        setState(() {
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

  List<AiOrderResult> _buildAiOrderResults(OrderRunResult result) {
    return List<AiOrderResult>.generate(result.ordersTarget, (index) {
      final orderNumber = index + 1;
      OrderLoopMetrics? metric;
      for (final candidate in result.loopMetrics) {
        if (candidate.loopIndex == orderNumber) {
          metric = candidate;
          break;
        }
      }
      final items = _orderScenario.getItemsForIteration(orderNumber);
      final itemSummary = items
          .map((item) {
            final type = item.isWeighed
                ? 'weighed${item.weight == null ? '' : ' ${item.weight} kg'}'
                : item.type.name;
            return 'SKU ${item.skuCode} · $type · ${item.entryMode.name}';
          })
          .join('\n');
      return AiOrderResult(
        orderNumber: orderNumber,
        itemSummary: itemSummary.isEmpty
            ? 'No item details recorded'
            : itemSummary,
        passed: metric != null,
        durationMs: metric?.durationMs ?? 0,
        cashAmount: metric?.payableCash ?? 0,
      );
    });
  }

  void _addMessage(String title, String body, QaActivityKind kind) {
    setState(() {
      _messages.add(QaActivityMessage(title, body, kind));
    });
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
    flutterPath: _flutterPath,
    appRoot: _appRoot,
    onProfileSelected: _selectProfile,
    onProfilesUpdated: (profiles) => setState(() => _profiles = profiles),
    onAiModelConfigUpdated: (config) => setState(() => _aiModelConfig = config),
    onClose: () => setState(() => _showSettingsScreen = false),
  );

  Widget _buildAssistantWorkspace() => _AiAssistantWorkspaceHost(
    key: _workspaceKey,
    profiles: _profiles,
    activeProfile: _profile,
    modelConfigured: _aiModelConfig.isConfigured,
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
    executionSteps: _executionSteps,
    executionSuiteTitle: _executionSuiteTitle,
    executionProfileLabel: _executionProfileLabel,
    showActivityDetails: _aiModelConfig.enableVerboseReasoning,
    onSend: _respondToAi,
    onRunPlan: _runAiPlan,
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
          child: QaActivityPanel(messages: _messages),
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

// ---------------------------------------------------------------------------
// Wrapper that holds a GlobalKey-accessible reference to the workspace's
// internal message list so the dashboard can inject rich report messages.
// ---------------------------------------------------------------------------

class _AiAssistantWorkspaceHost extends StatefulWidget {
  const _AiAssistantWorkspaceHost({
    super.key,
    required this.profiles,
    required this.activeProfile,
    required this.modelConfigured,
    required this.running,
    required this.messages,
    required this.onAddMessage,
    this.onTruncateMessages,
    this.onPlanningStateChanged,
    required this.activityMessages,
    required this.executionSteps,
    required this.executionSuiteTitle,
    required this.executionProfileLabel,
    this.showActivityDetails = false,
    required this.onSend,
    required this.onRunPlan,
    required this.onOpenSettings,
    required this.onExitAiMode,
  });

  final List<QaProfile> profiles;
  final QaProfile activeProfile;
  final bool modelConfigured;
  final bool running;
  final bool showActivityDetails;
  final List<AiChatMessage> messages;
  final ValueChanged<AiChatMessage> onAddMessage;
  final ValueChanged<int>? onTruncateMessages;
  final ValueChanged<bool>? onPlanningStateChanged;
  final List<QaActivityMessage> activityMessages;
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

  @override
  State<_AiAssistantWorkspaceHost> createState() =>
      _AiAssistantWorkspaceHostState();
}

class _AiAssistantWorkspaceHostState extends State<_AiAssistantWorkspaceHost> {
  @override
  Widget build(BuildContext context) {
    return AiAssistantWorkspace(
      profiles: widget.profiles,
      activeProfile: widget.activeProfile,
      modelConfigured: widget.modelConfigured,
      running: widget.running,
      messages: widget.messages,
      onAddMessage: widget.onAddMessage,
      onTruncateMessages: widget.onTruncateMessages,
      onPlanningStateChanged: widget.onPlanningStateChanged,
      showActivityDetails: widget.showActivityDetails,
      activityMessages: widget.activityMessages,
      executionSteps: widget.executionSteps,
      executionSuiteTitle: widget.executionSuiteTitle,
      executionProfileLabel: widget.executionProfileLabel,
      onSend: widget.onSend,
      onRunPlan: widget.onRunPlan,
      onOpenSettings: widget.onOpenSettings,
      onExitAiMode: widget.onExitAiMode,
    );
  }
}
