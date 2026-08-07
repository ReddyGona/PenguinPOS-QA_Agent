import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/ai_orchestrator.dart';
import 'package:penguin_pos_qa_agent/ai/orchestration/slash_command_parser.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

void main() {
  group('AI planning guardrails', () {
    final profiles = <QaProfile>[QaProfile.values[1], QaProfile.values[3]];

    test('slash command selects only a configured profile and workflow', () {
      final response = SlashCommandParser().parse(
        '/kpn-dev /orders 3',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.plan!.profileId, 'kpn-dev');
      expect(response.plan!.workflow, AiWorkflow.orderCashPayment);
      expect(response.plan!.ordersCount, 3);
      expect(response.state, AiPlanState.needsInput);
      expect(
        response.missingFields,
        containsAll(<String>['itemStrategy', 'items']),
      );
    });

    test('unknown profile cannot produce a runnable plan', () {
      final response = SlashCommandParser().parse(
        '/unknown-dev /login',
        profiles,
      );

      expect(response, isNotNull);
      expect(response!.plan, isNull);
      expect(response.missingFields, contains('profile'));
    });

    test(
      'natural language without a configured provider never executes a plan',
      () async {
        final response = await AiOrchestrator(
          profiles: profiles,
          provider: null,
        ).respond(input: 'run anything you want', history: <AiChatMessage>[]);

        expect(response.state, AiPlanState.needsInput);
        expect(response.plan, isNull);
        expect(response.message, contains('Configure'));
      },
    );
  });
}
