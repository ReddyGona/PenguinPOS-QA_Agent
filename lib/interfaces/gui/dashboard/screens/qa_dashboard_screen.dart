import 'package:flutter/material.dart';

import '../../../../automation/login/login_runner.dart';
import '../../../../automation/login/login_scenario.dart';
import '../../../../runtime/app_launcher.dart';
import '../model/qa_dashboard_models.dart';
import '../repository/qa_target_preferences_repository.dart';
import '../widgets/qa_dashboard_widgets.dart';

class QaDashboardScreen extends StatefulWidget {
  const QaDashboardScreen({super.key});

  @override
  State<QaDashboardScreen> createState() => _QaDashboardScreenState();
}

class _QaDashboardScreenState extends State<QaDashboardScreen> {
  final _preferences = QaTargetPreferencesRepository();
  final _sshUser = TextEditingController();
  final _sshHost = TextEditingController();
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  QaTargetMode _targetMode = QaTargetMode.local;
  QaProfile? _profile;
  bool _testsUnlocked = false;
  bool _showTests = false;
  bool _running = false;
  final _messages = <QaActivityMessage>[
    const QaActivityMessage(
      'Ready',
      'Choose a target and QA profile to unlock the fixed test suite.',
      QaActivityKind.info,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _restoreSshTarget();
  }

  Future<void> _restoreSshTarget() async {
    final target = await _preferences.loadSshTarget();
    if (!mounted) return;
    setState(() {
      _sshUser.text = target.username;
      _sshHost.text = target.host;
    });
  }

  Future<void> _saveConfiguration() async {
    if (_profile == null) {
      _addMessage(
        'Configuration needed',
        'Select an entity and environment profile before continuing.',
        QaActivityKind.error,
      );
      return;
    }
    if (_targetMode == QaTargetMode.ssh &&
        (_sshUser.text.trim().isEmpty || _sshHost.text.trim().isEmpty)) {
      _addMessage(
        'SSH target needed',
        'Enter both SSH username and host/IP before continuing.',
        QaActivityKind.error,
      );
      return;
    }
    await _preferences.saveSshTarget(
      QaSshTarget(username: _sshUser.text.trim(), host: _sshHost.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      _testsUnlocked = true;
      _showTests = true;
    });
    _addMessage(
      'Configuration saved',
      _targetMode == QaTargetMode.local
          ? 'Local target with ${_profile!.label} is ready. The Login & Terminal suite is unlocked.'
          : 'SSH target ${_sshUser.text.trim()}@${_sshHost.text.trim()} is saved. Remote execution will be enabled in the SSH phase.',
      QaActivityKind.success,
    );
  }

  Future<void> _runLoginSuite() async {
    if (_targetMode == QaTargetMode.ssh) {
      _addMessage(
        'SSH execution pending',
        'The target is saved, but remote SSH execution is intentionally planned for the next phase.',
        QaActivityKind.info,
      );
      return;
    }
    if (_loginId.text.trim().length != 10 || _password.text.isEmpty) {
      _addMessage(
        'Credentials needed',
        'Enter a 10-digit login ID and test password. Password is not saved.',
        QaActivityKind.error,
      );
      return;
    }
    final profile = _profile;
    if (profile == null) return;
    setState(() => _running = true);
    _addMessage(
      'Processing',
      'Launching local PenguinPOS for ${profile.label} and running the fixed Login & Terminal suite.',
      QaActivityKind.info,
    );
    LaunchedPenguinPos? launched;
    try {
      launched = await PenguinPosAppLauncher().launch(
        appRoot: PenguinPosAppLauncher.defaultAppRoot,
        entity: profile.entity,
        env: profile.environment,
      );
      final result = await PenguinPosLoginRunner().runFullSequence(
        LoginScenario(
          id: 'login_terminal_full_sequence',
          name: 'Login and terminal selection',
          loginId: _loginId.text.trim(),
          password: _password.text,
        ),
        vmServiceUri: launched.vmServiceUri,
      );
      _addMessage(
        result.passed ? 'Suite passed' : 'Suite failed',
        result.passed
            ? 'Completed: ${result.scenariosExecuted.join(', ')}.'
            : (result.error ??
                  'The driver did not reach the expected UI state.'),
        result.passed ? QaActivityKind.success : QaActivityKind.error,
      );
    } catch (error) {
      _addMessage('Suite failed', error.toString(), QaActivityKind.error);
    } finally {
      await launched?.close();
      if (mounted) setState(() => _running = false);
    }
  }

  void _addMessage(String title, String body, QaActivityKind kind) {
    if (!mounted) return;
    setState(() => _messages.add(QaActivityMessage(title, body, kind)));
  }

  @override
  void dispose() {
    _sshUser.dispose();
    _sshHost.dispose();
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: <Widget>[
        QaDashboardNavigation(
          showTests: _showTests,
          testsUnlocked: _testsUnlocked,
          onSetup: () => setState(() => _showTests = false),
          onTests: () => setState(() => _showTests = true),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 6,
                  child: _showTests ? _buildTests() : _buildSetup(),
                ),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: QaActivityPanel(messages: _messages)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSetup() => QaPanel(
    title: 'Run configuration',
    subtitle:
        'Choose where the deterministic QA suite will run, then select the global PenguinPOS profile.',
    child: ListView(
      children: <Widget>[
        const QaSectionTitle('Execution target'),
        const SizedBox(height: 10),
        SegmentedButton<QaTargetMode>(
          segments: const <ButtonSegment<QaTargetMode>>[
            ButtonSegment(
              value: QaTargetMode.local,
              label: Text('Local'),
              icon: Icon(Icons.laptop_mac_outlined),
            ),
            ButtonSegment(
              value: QaTargetMode.ssh,
              label: Text('Via SSH'),
              icon: Icon(Icons.terminal_outlined),
            ),
          ],
          selected: <QaTargetMode>{_targetMode},
          onSelectionChanged: (value) =>
              setState(() => _targetMode = value.first),
        ),
        if (_targetMode == QaTargetMode.ssh) ...<Widget>[
          const SizedBox(height: 20),
          const QaSectionTitle('Saved SSH target'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _sshUser,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sshHost,
                  decoration: const InputDecoration(
                    labelText: 'IP address or SSH host alias',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Username and host are saved locally. Passwords and private keys are never stored by this GUI.',
            ),
          ),
        ],
        const SizedBox(height: 28),
        const QaSectionTitle('Global QA profile'),
        const SizedBox(height: 6),
        const Text('This setting applies to every suite in the run.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: QaProfile.values
              .map(
                (profile) => ChoiceChip(
                  label: Text(profile.label),
                  selected: _profile == profile,
                  onSelected: (_) => setState(() => _profile = profile),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _saveConfiguration,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue to test cases'),
        ),
      ],
    ),
  );

  Widget _buildTests() => QaPanel(
    title: 'Test cases',
    subtitle:
        'Profile: ${_profile?.label ?? 'not selected'} · Target: ${_targetMode == QaTargetMode.local ? 'Local machine' : 'SSH target'}',
    child: ListView(
      children: <Widget>[
        const QaSectionTitle('Login & terminal selection'),
        const SizedBox(height: 6),
        const Text(
          'Runs fixed checks: empty credential validation, invalid credentials, valid login, terminal Continue, and home-screen navigation.',
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _loginId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Test login ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Test password',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Credentials are used only for this run and are never saved or displayed in the activity panel.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _running ? null : _runLoginSuite,
          icon: _running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_running ? 'Processing…' : 'Run Login & Terminal suite'),
        ),
        if (_targetMode == QaTargetMode.ssh)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'SSH configuration is ready, but its executor is intentionally deferred to the next phase.',
            ),
          ),
      ],
    ),
  );
}
