import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh/open_ssh_transport.dart';
import 'package:penguin_pos_qa_agent/runtime/ssh_app_launcher.dart';

/// Tab view for configuring remote POS SSH connection and tunnel parameters.
class SshSettingsTab extends StatefulWidget {
  const SshSettingsTab({
    super.key,
    required this.initialTargetMode,
    required this.initialConfig,
    required this.onTargetModeChanged,
    required this.onConfigSaved,
  });

  final QaTargetMode initialTargetMode;
  final QaSshConfig? initialConfig;
  final ValueChanged<QaTargetMode> onTargetModeChanged;
  final ValueChanged<QaSshConfig> onConfigSaved;

  @override
  State<SshSettingsTab> createState() => _SshSettingsTabState();
}

class _SshSettingsTabState extends State<SshSettingsTab> {
  late QaTargetMode _targetMode;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _userController;
  late final TextEditingController _keyPathController;
  late final TextEditingController _remoteAppRootController;
  late final TextEditingController _remoteFlutterController;
  late final TextEditingController _remoteDisplayController;
  late final TextEditingController _vmPortController;
  late SshLaunchMethod _launchMethod;

  bool _testingConnection = false;
  String? _testResult;
  bool _testPassed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _targetMode = widget.initialTargetMode;
    final config = widget.initialConfig;

    _hostController = TextEditingController(text: config?.host ?? '');
    _portController = TextEditingController(
      text: (config?.port ?? 22).toString(),
    );
    _userController = TextEditingController(text: config?.username ?? '');
    _keyPathController = TextEditingController(
      text: config?.privateKeyPath ?? '',
    );
    _remoteAppRootController = TextEditingController(
      text:
          config?.remoteAppRoot ??
          (_userController.text.isNotEmpty
              ? '/home/${_userController.text}/Documents/penguin_pos'
              : '/home/savo/Documents/penguin_pos'),
    );
    _remoteFlutterController = TextEditingController(
      text: config?.remoteFlutterExecutable ?? 'flutter',
    );
    _remoteDisplayController = TextEditingController(
      text: config?.remoteDisplay ?? ':0',
    );
    _vmPortController = TextEditingController(
      text: (config?.vmServicePort ?? 8888).toString(),
    );
    _prebuiltBinaryPathController = TextEditingController(
      text:
          config?.prebuiltBinaryPath ??
          './build/linux/x64/debug/bundle/penguin_pos',
    );
    _launchMethod = config?.launchMethod ?? SshLaunchMethod.flutterRun;
  }

  late final TextEditingController _prebuiltBinaryPathController;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _keyPathController.dispose();
    _remoteAppRootController.dispose();
    _remoteFlutterController.dispose();
    _remoteDisplayController.dispose();
    _vmPortController.dispose();
    _prebuiltBinaryPathController.dispose();
    super.dispose();
  }

  QaSshConfig _buildCurrentConfig() {
    return QaSshConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _userController.text.trim(),
      privateKeyPath: _keyPathController.text.trim().isEmpty
          ? null
          : _keyPathController.text.trim(),
      remoteAppRoot: _remoteAppRootController.text.trim(),
      remoteFlutterExecutable: _remoteFlutterController.text.trim().isEmpty
          ? 'flutter'
          : _remoteFlutterController.text.trim(),
      remoteDisplay: _remoteDisplayController.text.trim().isEmpty
          ? ':0'
          : _remoteDisplayController.text.trim(),
      vmServicePort: int.tryParse(_vmPortController.text.trim()) ?? 8888,
      launchMethod: _launchMethod,
      prebuiltBinaryPath: _prebuiltBinaryPathController.text.trim().isEmpty
          ? './build/linux/x64/debug/bundle/penguin_pos'
          : _prebuiltBinaryPathController.text.trim(),
    );
  }

  Future<void> _pickPrivateKey() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select SSH Private Key',
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _keyPathController.text = result.files.single.path!;
        });
      }
    } catch (_) {}
  }

  Future<void> _testConnection() async {
    final config = _buildCurrentConfig();
    final issues = config.validate();
    if (issues.isNotEmpty) {
      setState(() {
        _testResult = issues.first;
        _testPassed = false;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    final launcher = SshAppLauncher();
    final error = await launcher.testConnection(config);

    if (mounted) {
      setState(() {
        _testingConnection = false;
        _testPassed = error == null;
        _testResult =
            error ??
            'SSH connection verified! Host is reachable and app directory exists.';
      });
    }
  }

  void _save() {
    final config = _buildCurrentConfig();
    setState(() => _saving = true);
    widget.onTargetModeChanged(_targetMode);
    widget.onConfigSaved(config);
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SSH Remote POS settings saved successfully.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'SSH Remote POS Target',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure connection to a physical Ubuntu Posiflex device to launch and drive PenguinPOS over SSH.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            const Text(
              'Active Target Execution Mode',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _targetMode = QaTargetMode.local),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _targetMode == QaTargetMode.local
                            ? const Color(0xFFDCE4DF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _targetMode == QaTargetMode.local
                              ? const Color(0xFF658A7A)
                              : const Color(0xFFE0DDD5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.laptop_mac_rounded,
                            size: 20,
                            color: _targetMode == QaTargetMode.local
                                ? const Color(0xFF182A22)
                                : const Color(0xFF787A76),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Local macOS Host',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Runs PenguinPOS locally on this Mac',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF787A76),
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
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _targetMode = QaTargetMode.ssh),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _targetMode == QaTargetMode.ssh
                            ? const Color(0xFFDCE4DF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _targetMode == QaTargetMode.ssh
                              ? const Color(0xFF658A7A)
                              : const Color(0xFFE0DDD5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.lan_outlined,
                            size: 20,
                            color: _targetMode == QaTargetMode.ssh
                                ? const Color(0xFF182A22)
                                : const Color(0xFF787A76),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Remote POS (SSH)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Drives Ubuntu Posiflex over SSH tunnel',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF787A76),
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
              ],
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Remote SSH Host & Credentials',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Host IP / Domain',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 10.3.10.210 or pos1.local',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SSH Port',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '22',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'SSH Username',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _userController,
                        decoration: InputDecoration(
                          hintText: 'e.g. savo or counter1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'SSH Key (Optional — leave empty to use SSH agent / default keys)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _keyPathController,
                    decoration: InputDecoration(
                      hintText:
                          'e.g. ~/.ssh/id_rsa or /Users/name/.ssh/pos_key',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickPrivateKey,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Browse'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Remote PenguinPOS Environment & Launch Parameters',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            const Text(
              'Remote PenguinPOS Directory',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _remoteAppRootController,
              decoration: InputDecoration(
                hintText: '/home/savo/Documents/penguin_pos',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Remote Flutter Executable',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _remoteFlutterController,
                        decoration: InputDecoration(
                          hintText:
                              '/home/savo/Documents/flutter/bin/flutter or flutter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'DISPLAY',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _remoteDisplayController,
                        decoration: InputDecoration(
                          hintText: ':0',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'VM Service Port',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _vmPortController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '8888',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Launch Method',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<SshLaunchMethod>(
              initialValue: _launchMethod,
              isDense: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: const <DropdownMenuItem<SshLaunchMethod>>[
                DropdownMenuItem(
                  value: SshLaunchMethod.prebuiltBinary,
                  child: Text(
                    'Pre-built Bundle (Instant 0.2s Launch — Recommended)',
                  ),
                ),
                DropdownMenuItem(
                  value: SshLaunchMethod.flutterRun,
                  child: Text('flutter run -d linux (Build from source)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _launchMethod = val);
              },
            ),
            const SizedBox(height: 16),

            if (_launchMethod == SshLaunchMethod.prebuiltBinary) ...<Widget>[
              const Text(
                'Pre-built Binary Bundle Path (Relative to Remote App Root)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _prebuiltBinaryPathController,
                decoration: InputDecoration(
                  hintText: './build/linux/x64/debug/bundle/penguin_pos',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),

            if (_testResult != null) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _testPassed
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testPassed
                        ? const Color(0xFF81C784)
                        : const Color(0xFFE57373),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          _testPassed
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: _testPassed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _testPassed
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFB71C1C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_testPassed &&
                        (_testResult!.contains('host key') ||
                            _testResult!.contains('Host key') ||
                            _testResult!.contains('known'))) ...<Widget>[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final config = _buildCurrentConfig();
                          final transport = OpenSshTransport();
                          await transport.trustHostKey(
                            host: config.host,
                            port: config.port,
                            knownHostsPath:
                                config.knownHostsPath ??
                                '/Users/reddygona/.penguin_pos_qa/known_hosts',
                          );
                          await _testConnection();
                        },
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                        ),
                        label: const Text(
                          'Trust & Approve Host Key',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: Text(
                    _testingConnection
                        ? 'Testing Connection...'
                        : 'Test SSH Connection',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save SSH Configuration'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF658A7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
