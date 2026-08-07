import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'interfaces/gui/qa_agent_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 820),
    minimumSize: Size(1050, 700),
    center: true,
    title: 'PenguinPOS QA Agent',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const QaAgentGuiApp());
}
