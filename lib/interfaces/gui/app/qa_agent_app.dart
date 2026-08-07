import 'package:flutter/material.dart';

import '../dashboard/screens/qa_dashboard_screen.dart';

class QaAgentGuiApp extends StatelessWidget {
  const QaAgentGuiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PenguinPOS QA Agent',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF155EEF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    ),
    home: const QaDashboardScreen(),
  );
}
