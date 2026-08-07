import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Interactive 3-step setup onboarding wizard for target, environment, and credentials configuration.
class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({
    super.key,
    required this.initialTargetMode,
    required this.initialFlutterPath,
    required this.initialAppRoot,
    required this.initialProfile,
    required this.initialLoginId,
    required this.initialPassword,
    required this.initialUnlockPin,
    required this.onComplete,
  });

  final QaTargetMode initialTargetMode;
  final String initialFlutterPath;
  final String initialAppRoot;
  final QaProfile? initialProfile;
  final String initialLoginId;
  final String initialPassword;
  final String initialUnlockPin;

  final void Function({
    required QaTargetMode targetMode,
    required String flutterPath,
    required String appRoot,
    required QaProfile profile,
    required String loginId,
    required String password,
    required String unlockPin,
    required String sshUser,
    required String sshHost,
  })
  onComplete;

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  int _currentStep = 0;

  late QaTargetMode _targetMode;
  late TextEditingController _flutterPathController;
  late TextEditingController _appRootController;
  late TextEditingController _sshUserController;
  late TextEditingController _sshHostController;

  QaProfile? _selectedProfile;

  late TextEditingController _loginIdController;
  late TextEditingController _passwordController;
  late TextEditingController _unlockPinController;

  bool _detectingPaths = false;
  bool _flutterPathValid = true;
  bool _appRootValid = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _targetMode = widget.initialTargetMode;
    _flutterPathController = TextEditingController(
      text: widget.initialFlutterPath,
    );
    _appRootController = TextEditingController(text: widget.initialAppRoot);
    _sshUserController = TextEditingController();
    _sshHostController = TextEditingController();
    _selectedProfile = widget.initialProfile ?? QaProfile.values.first;
    _loginIdController = TextEditingController(text: widget.initialLoginId);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _unlockPinController = TextEditingController(text: widget.initialUnlockPin);

    _autoDetectSystemPaths();
  }

  Future<void> _autoDetectSystemPaths() async {
    setState(() => _detectingPaths = true);
    try {
      if (_flutterPathController.text.isEmpty ||
          _flutterPathController.text == 'flutter') {
        final detectedFlutter = await PathDetector.detectFlutterPath();
        _flutterPathController.text = detectedFlutter;
      }
      if (_appRootController.text.isEmpty) {
        final detectedAppRoot = await PathDetector.detectAppRoot();
        _appRootController.text = detectedAppRoot;
      }

      _flutterPathValid = await PathDetector.isValidFlutterExecutable(
        _flutterPathController.text,
      );
      _appRootValid = await PathDetector.isValidAppRoot(
        _appRootController.text,
      );
    } finally {
      if (mounted) {
        setState(() => _detectingPaths = false);
      }
    }
  }

  @override
  void dispose() {
    _flutterPathController.dispose();
    _appRootController.dispose();
    _sshUserController.dispose();
    _sshHostController.dispose();
    _loginIdController.dispose();
    _passwordController.dispose();
    _unlockPinController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    setState(() => _errorMessage = null);
    if (_currentStep == 0) {
      if (_flutterPathController.text.trim().isEmpty) {
        setState(
          () => _errorMessage =
              'Please provide or auto-detect a valid Flutter executable path.',
        );
        return;
      }
      if (_appRootController.text.trim().isEmpty) {
        setState(
          () => _errorMessage =
              'Please provide or auto-detect a valid PenguinPOS app root directory.',
        );
        return;
      }
      if (_targetMode == QaTargetMode.ssh &&
          (_sshUserController.text.trim().isEmpty ||
              _sshHostController.text.trim().isEmpty)) {
        setState(
          () => _errorMessage = 'Please enter SSH username and host/IP.',
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedProfile == null) {
        setState(
          () => _errorMessage = 'Please select a QA Profile to continue.',
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final loginId = _loginIdController.text.trim();
      final password = _passwordController.text;
      final unlockPin = _unlockPinController.text.trim();

      if (loginId.length != 10) {
        setState(() => _errorMessage = 'Login ID must be exactly 10 digits.');
        return;
      }
      if (password.isEmpty) {
        setState(() => _errorMessage = 'Password cannot be empty.');
        return;
      }

      widget.onComplete(
        targetMode: _targetMode,
        flutterPath: _flutterPathController.text.trim(),
        appRoot: _appRootController.text.trim(),
        profile: _selectedProfile!,
        loginId: loginId,
        password: password,
        unlockPin: unlockPin,
        sshUser: _sshUserController.text.trim(),
        sshHost: _sshHostController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'PenguinPOS QA Agent Setup',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Configure your environment before unlocking test suites',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Step ${_currentStep + 1} of 3',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress Indicator Bar
                LinearProgressIndicator(
                  value: (_currentStep + 1) / 3.0,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF155EEF),
                ),

                // Content Area
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_currentStep == 0) _buildStep1TargetAndPaths(),
                      if (_currentStep == 1) _buildStep2Environment(),
                      if (_currentStep == 2) _buildStep3Credentials(),
                    ],
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _errorMessage = null;
                            _currentStep--;
                          }),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF155EEF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _nextStep,
                        icon: Icon(
                          _currentStep == 2
                              ? Icons.check_circle
                              : Icons.arrow_forward,
                        ),
                        label: Text(
                          _currentStep == 2 ? 'Unlock Workspace' : 'Next Step',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1TargetAndPaths() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Step 1: Execution Target & System Paths',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose where tests run and verify Flutter & PenguinPOS paths.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),

        // Target Selection Cards
        Row(
          children: <Widget>[
            Expanded(
              child: _buildTargetCard(
                mode: QaTargetMode.local,
                title: 'Local Machine',
                subtitle: 'Runs PenguinPOS app directly on this computer.',
                icon: Icons.laptop_mac_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTargetCard(
                mode: QaTargetMode.ssh,
                title: 'Remote SSH Target',
                subtitle: 'Connects to a remote POS terminal over SSH.',
                icon: Icons.terminal_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_targetMode == QaTargetMode.ssh) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _sshUserController,
                  decoration: const InputDecoration(
                    labelText: 'SSH Username',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sshHostController,
                  decoration: const InputDecoration(
                    labelText: 'SSH Host / IP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Path configurations
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'System Paths Configuration',
                style: TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _detectingPaths ? null : _autoDetectSystemPaths,
              icon: _detectingPaths
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, size: 16),
              label: const Text('Auto-Detect Paths'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _flutterPathController,
          decoration: InputDecoration(
            labelText: 'Flutter Executable Path',
            hintText: '/opt/homebrew/bin/flutter or /usr/local/bin/flutter',
            prefixIcon: const Icon(Icons.code_rounded),
            suffixIcon: Icon(
              _flutterPathValid ? Icons.check_circle : Icons.warning_rounded,
              color: _flutterPathValid ? Colors.green : Colors.orange,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) async {
            final valid = await PathDetector.isValidFlutterExecutable(
              val.trim(),
            );
            if (mounted) setState(() => _flutterPathValid = valid);
          },
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _appRootController,
          decoration: InputDecoration(
            labelText: 'PenguinPOS App Root Directory',
            hintText: '/Users/username/Documents/PenguinPOS/penguin_pos',
            prefixIcon: const Icon(Icons.folder_open_rounded),
            suffixIcon: Icon(
              _appRootValid ? Icons.check_circle : Icons.warning_rounded,
              color: _appRootValid ? Colors.green : Colors.orange,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (val) async {
            final valid = await PathDetector.isValidAppRoot(val.trim());
            if (mounted) setState(() => _appRootValid = valid);
          },
        ),
      ],
    );
  }

  Widget _buildTargetCard({
    required QaTargetMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _targetMode == mode;
    return InkWell(
      onTap: () => setState(() => _targetMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF155EEF) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: selected ? const Color(0xFF155EEF) : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFF155EEF)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Environment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Step 2: Environment & Profile Selection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select entity branding and target backend deployment.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),

        const Text(
          'Choose Profile:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: QaProfile.values.map((profile) {
            final selected = _selectedProfile == profile;
            return ChoiceChip(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              selectedColor: const Color(0xFF155EEF),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              label: Text(profile.label),
              selected: selected,
              onSelected: (_) => setState(() => _selectedProfile = profile),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        if (_selectedProfile != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline, color: Color(0xFF155EEF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selected Entity: ${_selectedProfile!.entity.toUpperCase()} · Environment: ${_selectedProfile!.environment.toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep3Credentials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Step 3: Test Credentials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide the login credentials used to authenticate POS tests.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _loginIdController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: '10-Digit Test Login ID',
            hintText: 'e.g. 8888888888',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Test Password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _unlockPinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Terminal Unlock PIN (optional)',
            helperText:
                'Required only if PenguinPOS starts with an idle-locked session.',
            prefixIcon: Icon(Icons.pin_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          '🔒 Credentials are used in-memory for test drivers and are never saved to disk.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
