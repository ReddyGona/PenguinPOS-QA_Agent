import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

/// Fast local shortcuts. These never invoke the model and never execute a test.
class SlashCommandParser {
  AiAssistantResponse? parse(
    String input,
    List<QaProfile> profiles, {
    AiWorkflow? pendingWorkflow,
    List<String>? pendingMissingFields,
  }) {
    final rawTokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    final hasSlashToken = rawTokens.any((token) => token.startsWith('/'));

    // Slot-filling continuation for pending structured requests (e.g. missing profile)
    if (!hasSlashToken &&
        pendingWorkflow != null &&
        pendingMissingFields != null &&
        pendingMissingFields.contains('profile')) {
      final matchedProfile = findProfileInInput(input, profiles);
      if (matchedProfile != null) {
        return _buildResponseForWorkflowAndProfile(
          pendingWorkflow,
          matchedProfile,
        );
      }
    }

    if (rawTokens.isEmpty || !hasSlashToken) {
      return null;
    }

    final profile = findProfileInInput(input, profiles);
    AiWorkflow? workflow;
    var ordersCount = 1;

    for (var index = 0; index < rawTokens.length; index++) {
      final token = rawTokens[index].replaceFirst('/', '');
      if (token == 'login') workflow = AiWorkflow.loginFullSequence;
      if (token == 'orders' || token == 'order') {
        workflow = AiWorkflow.orderCashPayment;
        if (index + 1 < rawTokens.length) {
          ordersCount = int.tryParse(rawTokens[index + 1])?.clamp(1, 50) ?? 1;
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
        plan: null,
        message:
            'Choose an approved target profile, for example `${profiles.isEmpty ? 'kpn-stage' : profiles.first.id}`.',
        missingFields: const <String>['profile'],
        pendingRequest: AiPendingRequest(
          workflow: workflow,
          missingFields: const <String>['profile'],
          ordersCount: ordersCount,
        ),
      );
    }

    return _buildResponseForWorkflowAndProfile(
      workflow,
      profile,
      ordersCount: ordersCount,
    );
  }

  /// Handles unambiguous login requests without sending them to a model.
  ///
  /// Login is a fixed workflow, so phrases such as "test login in kpn dev"
  /// should have the same deterministic behaviour as `/login`. Keeping this
  /// here also means profile matching and the pending-profile flow stay in one
  /// place.
  AiAssistantResponse? parseNaturalWorkflow(
    String input,
    List<QaProfile> profiles,
  ) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty ||
        !RegExp(r'\b(login|log\s+in|sign\s+in)\b').hasMatch(normalized) ||
        RegExp(
          r'\b(explain|what|how|why|meaning|define)\b',
        ).hasMatch(normalized)) {
      return null;
    }

    final profile = findProfileInInput(input, profiles);
    if (profile == null) {
      return AiAssistantResponse(
        state: AiPlanState.needsInput,
        message:
            'Choose an approved target profile, for example `${profiles.isEmpty ? 'kpn-stage' : profiles.first.id}`.',
        missingFields: const <String>['profile'],
        pendingRequest: const AiPendingRequest(
          workflow: AiWorkflow.loginFullSequence,
          missingFields: <String>['profile'],
        ),
      );
    }

    return _buildResponseForWorkflowAndProfile(
      AiWorkflow.loginFullSequence,
      profile,
    );
  }

  AiAssistantResponse _buildResponseForWorkflowAndProfile(
    AiWorkflow workflow,
    QaProfile profile, {
    int ordersCount = 1,
  }) {
    final plan = AiTestPlan(
      workflow: workflow,
      profileId: profile.id,
      ordersCount: ordersCount,
    );

    if (workflow == AiWorkflow.loginFullSequence) {
      return AiAssistantResponse(
        state: AiPlanState.readyForConfirmation,
        plan: plan,
        message:
            'Login flow selected for ${profile.label}. Review the plan to proceed with preflight checks.',
      );
    }

    return AiAssistantResponse(
      state: AiPlanState.needsInput,
      plan: plan,
      message:
          '${ordersCount == 1 ? 'One order' : '$ordersCount orders'} selected for ${profile.label}. Should all orders use the same SKU list, or do you need individual SKU lists?',
      missingFields: const <String>['itemStrategy', 'items'],
      pendingRequest: AiPendingRequest(
        workflow: workflow,
        profileId: profile.id,
        ordersCount: ordersCount,
        missingFields: const <String>['itemStrategy', 'items'],
        partialPlan: plan,
      ),
    );
  }

  /// Finds a profile matching 2-word spans, 1-word spans, or full input normalization.
  QaProfile? findProfileInInput(String input, List<QaProfile> profiles) {
    if (input.trim().isEmpty || profiles.isEmpty) return null;

    final tokens = input
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('/', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    // 1. Check 2-word spans (longer match takes priority)
    for (var i = 0; i < tokens.length - 1; i++) {
      final span = '${tokens[i]} ${tokens[i + 1]}';
      final normalizedSpan = _normalize(span);
      for (final profile in profiles) {
        if (_matchesProfile(normalizedSpan, profile)) {
          return profile;
        }
      }
    }

    // 2. Check 1-word spans
    for (final token in tokens) {
      final normalizedToken = _normalize(token);
      for (final profile in profiles) {
        if (_matchesProfile(normalizedToken, profile)) {
          return profile;
        }
      }
    }

    // 3. Check full normalized input
    final fullNormalized = _normalize(input);
    for (final profile in profiles) {
      if (_matchesProfile(fullNormalized, profile)) {
        return profile;
      }
    }

    return null;
  }

  bool _matchesProfile(String normalizedInput, QaProfile profile) {
    if (normalizedInput.isEmpty) return false;
    final candidates = <String>[
      profile.id,
      profile.label,
      '${profile.entity} ${profile.environment}',
      '${profile.entity}${profile.environment}',
      ...profile.aliases,
    ];

    if (candidates.any((c) => _normalize(c) == normalizedInput)) {
      return true;
    }

    // Entity + environment stem matching (e.g. "kpn staging" matching "kpn-stage")
    final normEntity = _normalize(profile.entity);
    final normEnv = _normalize(profile.environment);
    final envStem = normEnv.length >= 4 ? normEnv.substring(0, 4) : normEnv;

    if (normEntity.isNotEmpty &&
        envStem.isNotEmpty &&
        normalizedInput.contains(normEntity) &&
        normalizedInput.contains(envStem)) {
      return true;
    }

    return false;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
