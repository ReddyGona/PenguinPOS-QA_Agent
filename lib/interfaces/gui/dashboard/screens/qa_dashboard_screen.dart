import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/automation/login/login_runner.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/onboarding/screens/onboarding_setup_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/qa_activity_panel.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/widgets/side_nav.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/login/login_suite_screen.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/order_suite_screen.dart';

/// Main Dashboard container screen managing setup state, sidebar navigation, active suite screen, and activity log matching the mockup.
class QaDashboardScreen extends StatefulWidget {
  const QaDashboardScreen({super.key});

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  final _preferences = QaTargetPreferencesRepository();

  bool _setupCompleted = false;

  QaTargetMode _targetMode = QaTargetMode.local;
  String _flutterPath = 'flutter';
  String _appRoot = '/Users/reddygona/Documents/PenguinPOS/penguin_pos';
  QaProfile _profile = QaProfile.values.first;
  String _loginId = '';
  String _password = '';
  String _unlockPin = '';
  String _sshUser = '';
  String _sshHost = '';

  String _selectedSuiteId = 'login_terminal';
  OrderScenario _orderScenario = OrderScenario.sampleScenario;

  bool _running = false;
  bool _stopRequested = false;
  LaunchedPenguinPos? _activeLaunch;
  Duration? _lastExecutionDuration;
  bool? _lastExecutionPassed;
  String? _lastExecutionDetails;
  bool _wasAppClosedByUser = false;
  List<String> _scenariosCompletedSoFar = <String>[];
  OrderRunResult? _lastOrderRunResult;

  final _messages = <QaActivityMessage>[
    QaActivityMessage(
      'Ready',
      'Complete onboarding setup to unlock the workspace.',
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
    final detectedFlutter = await PathDetector.detectFlutterPath();
    final detectedAppRoot = await PathDetector.detectAppRoot();

    if (!mounted) return;
    setState(() {
      _sshUser = target.username;
      _sshHost = target.host;
      _flutterPath = detectedFlutter;
      _appRoot = detectedAppRoot;
    });
  }

  void _onSetupComplete({
    required QaTargetMode targetMode,
    required String flutterPath,
    required String appRoot,
    required QaProfile profile,
    required String loginId,
    required String password,
    required String unlockPin,
    required String sshUser,
    required String sshHost,
  }) async {
    setState(() {
      _targetMode = targetMode;
      _flutterPath = flutterPath;
      _appRoot = appRoot;
      _profile = profile;
      _loginId = loginId;
      _password = password;
      _unlockPin = unlockPin;
      _sshUser = sshUser;
      _sshHost = sshHost;
      _setupCompleted = true;
    });

    if (sshUser.isNotEmpty || sshHost.isNotEmpty) {
      await _preferences.saveSshTarget(
        QaSshTarget(username: sshUser, host: sshHost),
      );
    }

    _addMessage(
      'Setup Configured',
      'Target: ${targetMode == QaTargetMode.local ? "Local Machine" : "SSH ($sshUser@$sshHost)"} · Profile: ${profile.label}',
      QaActivityKind.success,
    );
  }

  void _openEditCredentialsDialog() {
    final loginController = TextEditingController(text: _loginId);
    final passwordController = TextEditingController(text: _password);
    final unlockPinController = TextEditingController(text: _unlockPin);
    QaProfile tempProfile = _profile;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.key_rounded, color: Color(0xFF155EEF)),
              SizedBox(width: 10),
              Text('Credentials & Environment'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Target Profile / Environment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<QaProfile>(
                  initialValue: tempProfile,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: QaProfile.values
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => tempProfile = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Test Login ID (10-digits)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: loginController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 8888888888',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Test Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter password',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Terminal Unlock PIN',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: unlockPinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 1234 or 1359',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF155EEF),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _profile = tempProfile;
                  _loginId = loginController.text.trim();
                  _password = passwordController.text;
                  _unlockPin = unlockPinController.text.trim();
                });
                Navigator.pop(dialogContext);
                _addMessage(
                  'Credentials Updated',
                  'Profile: ${tempProfile.label} · Login ID: ${_loginId.isEmpty ? "(Prompt)" : _loginId}',
                  QaActivityKind.info,
                );
              },
              child: const Text('Save Credentials'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.settings_outlined, color: Color(0xFF155EEF)),
            SizedBox(width: 10),
            Text('QA Agent Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Flutter Path: $_flutterPath',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text('App Root: $_appRoot', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            const Text(
              'Execution Engine: FlutterDriver / VM Service',
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
    if (!mounted || _scenariosCompletedSoFar.contains(scenarioName)) return;
    setState(() => _scenariosCompletedSoFar.add(scenarioName));
  }

  String _interruptionDetails({required bool wasStopped}) => wasStopped
      ? 'Test stopped by the user. Completed test cases are retained; remaining cases are pending.'
      : 'PenguinPOS was quit during testing. Completed test cases are retained; remaining cases are pending.';

  Future<void> _runSelectedSuite() async {
    final currentSuite = TestSuiteItem.availableSuites.firstWhere(
      (s) => s.id == _selectedSuiteId,
      orElse: () => TestSuiteItem.availableSuites.first,
    );

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

    setState(() {
      _running = true;
      _lastExecutionPassed = null;
      _lastExecutionDetails = null;
      _wasAppClosedByUser = false;
      _stopRequested = false;
      _scenariosCompletedSoFar = <String>[];
    });

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
        );

        stopwatch.stop();

        setState(() {
          _lastExecutionDuration = stopwatch.elapsed;
          _lastExecutionPassed = result.passed;
          _wasAppClosedByUser = result.wasAppClosedByUser || _stopRequested;
          _scenariosCompletedSoFar = result.scenariosExecuted;
          _lastExecutionDetails = result.passed
              ? 'Successfully executed all scenarios: ${result.scenariosExecuted.join(', ')}.'
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
                ? 'Completed in ${stopwatch.elapsed.inSeconds}s (${result.scenariosExecuted.length} scenarios).'
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
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  void _addMessage(String title, String body, QaActivityKind kind) {
    setState(() {
      _messages.add(QaActivityMessage(title, body, kind));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_setupCompleted) {
      return OnboardingSetupScreen(
        initialTargetMode: _targetMode,
        initialFlutterPath: _flutterPath,
        initialAppRoot: _appRoot,
        initialProfile: _profile,
        initialLoginId: _loginId,
        initialPassword: _password,
        initialUnlockPin: _unlockPin,
        onComplete: _onSetupComplete,
      );
    }

    final activeSuite = TestSuiteItem.availableSuites.firstWhere(
      (s) => s.id == _selectedSuiteId,
      orElse: () => TestSuiteItem.availableSuites.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: <Widget>[
          // Left Sidebar
          SideNav(
            suites: TestSuiteItem.availableSuites,
            selectedSuiteId: _selectedSuiteId,
            onSelectSuite: (id) {
              setState(() {
                _selectedSuiteId = id;
                _lastExecutionPassed = null;
                _wasAppClosedByUser = false;
                _lastExecutionDetails = null;
                _scenariosCompletedSoFar = <String>[];
              });
            },
            onOpenSetup: () {
              setState(() => _setupCompleted = false);
            },
            onOpenEditCredentials: _openEditCredentialsDialog,
            onNewSuite: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Custom suite builder is planned for upcoming release.',
                  ),
                ),
              );
            },
            onOpenSettings: _openSettingsDialog,
            onOpenSupport: _openSupportDialog,
            activeProfileLabel: _profile.label,
            targetMode: _targetMode,
          ),

          // Main Active Test Suite Workspace
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _selectedSuiteId == 'order_checkout'
                  ? OrderSuiteScreen(
                      suite: activeSuite,
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
                      onUpdateScenario: (updated) {
                        setState(() => _orderScenario = updated);
                      },
                      onRunSuite: _runSelectedSuite,
                      onStopSuite: _stopRunningSuite,
                    )
                  : LoginSuiteScreen(
                      suite: activeSuite,
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
                      onProfileChanged: (p) => setState(() => _profile = p),
                      onLoginIdChanged: (id) => setState(() => _loginId = id),
                      onPasswordChanged: (pass) =>
                          setState(() => _password = pass),
                      onRunSuite: _runSelectedSuite,
                      onStopSuite: _stopRunningSuite,
                    ),
            ),
          ),

          // Right Activity Stepper Panel
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
              child: QaActivityPanel(messages: _messages),
            ),
          ),
        ],
      ),
    );
  }
}
