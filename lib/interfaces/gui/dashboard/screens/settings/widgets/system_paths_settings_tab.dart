import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

/// Tab view displaying auto-detected system paths and execution engine protocol.
class SystemPathsSettingsTab extends StatelessWidget {
  const SystemPathsSettingsTab({
    super.key,
    required this.flutterPath,
    required this.appRoot,
  });

  final String flutterPath;
  final String appRoot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Execution Engine & System Paths',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C302E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Auto-detected system paths used by the test execution driver to launch PenguinPOS.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
        ),
        const SizedBox(height: 24),

        SettingsFormCard(
          children: <Widget>[
            const Text(
              'Flutter Executable Path',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              flutterPath,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Color(0xFF494C4A),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'PenguinPOS Application Root Directory',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              appRoot,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Color(0xFF494C4A),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Execution Driver Protocol',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'FlutterDriver / WebSocket VM Service Protocol (v2.0)',
              style: TextStyle(fontSize: 13, color: Color(0xFF494C4A)),
            ),
          ],
        ),
      ],
    );
  }
}
