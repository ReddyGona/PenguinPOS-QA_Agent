import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/qa_agent_dashboard.dart';

void main() {
  testWidgets('shows configuration before test cases are unlocked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const QaAgentGuiApp());

    expect(find.text('PenguinPOS QA Agent Setup'), findsOneWidget);
    expect(find.text('Local Machine'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
  });
}
