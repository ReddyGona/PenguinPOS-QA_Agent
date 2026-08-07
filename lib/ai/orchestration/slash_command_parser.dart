import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Fast local shortcuts. These never invoke the model and never execute a test.
class SlashCommandParser {
  AiAssistantResponse? parse(String input, List<QaProfile> profiles) {
    final tokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty || !tokens.any((token) => token.startsWith('/'))) {
      return null;
    }

    QaProfile? profile;
    AiWorkflow? workflow;
    var ordersCount = 1;
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index].replaceFirst('/', '');
      profile ??= _findProfile(token, profiles);
      if (token == 'login') workflow = AiWorkflow.loginFullSequence;
      if (token == 'orders' || token == 'order') {
        workflow = AiWorkflow.orderCashPayment;
        if (index + 1 < tokens.length) {
          ordersCount = int.tryParse(tokens[index + 1])?.clamp(1, 50) ?? 1;
        }
      }
    }

    if (workflow == null) {
      return const AiAssistantResponse(
        state: AiPlanState.needsInput,
        message: 'Choose a workflow: `/login` or `/orders 3`.',
        missingFields: <String>['workflow'],
      );
    }

    if (profile == null) {
      return AiAssistantResponse(
        state: AiPlanState.needsInput,
        message:
            'Choose an approved target profile, for example `${profiles.first.id}`.',
        missingFields: const <String>['profile'],
      );
    }

    final plan = AiTestPlan(
      workflow: workflow,
      profileId: profile.id,
      ordersCount: ordersCount,
    );
    if (workflow == AiWorkflow.loginFullSequence) {
      return AiAssistantResponse(
        state: AiPlanState.needsInput,
        plan: plan,
        message:
            'Login flow selected for ${profile.label}. Please provide credentials through the secure Credentials & Environment form, then review the plan.',
        missingFields: const <String>['credentials'],
      );
    }

    return AiAssistantResponse(
      state: AiPlanState.needsInput,
      plan: plan,
      message:
          '${ordersCount == 1 ? 'One order' : '$ordersCount orders'} selected for ${profile.label}. Should all orders use the same SKU list, or do you need individual SKU lists?',
      missingFields: const <String>['itemStrategy', 'items'],
    );
  }

  QaProfile? _findProfile(String token, List<QaProfile> profiles) {
    for (final profile in profiles) {
      if (profile.id == token || profile.aliases.contains(token)) {
        return profile;
      }
    }
    return null;
  }
}
