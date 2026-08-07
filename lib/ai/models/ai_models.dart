import 'dart:convert';

import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';

enum AiProviderKind { openAiCompatible }

class AiModelConfig {
  const AiModelConfig({
    this.providerKind = AiProviderKind.openAiCompatible,
    this.label = 'Local OpenAI-compatible',
    this.baseUrl = 'http://127.0.0.1:11434/v1',
    this.model = '',
    this.isCloud = false,
    this.temperature = 0.1,
    this.maxOutputTokens = 1200,
    this.enableVerboseReasoning = false,
  });

  final AiProviderKind providerKind;
  final String label;
  final String baseUrl;
  final String model;
  final bool isCloud;
  final double temperature;
  final int maxOutputTokens;

  /// Debug-only: exposes model reasoning in the Assistant trace. It costs more
  /// tokens and can slow planning, so structured-plan mode keeps it off.
  final bool enableVerboseReasoning;

  bool get isConfigured => model.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  AiModelConfig copyWith({
    AiProviderKind? providerKind,
    String? label,
    String? baseUrl,
    String? model,
    bool? isCloud,
    double? temperature,
    int? maxOutputTokens,
    bool? enableVerboseReasoning,
  }) => AiModelConfig(
    providerKind: providerKind ?? this.providerKind,
    label: label ?? this.label,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    isCloud: isCloud ?? this.isCloud,
    temperature: temperature ?? this.temperature,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    enableVerboseReasoning:
        enableVerboseReasoning ?? this.enableVerboseReasoning,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'providerKind': providerKind.name,
    'label': label,
    'baseUrl': baseUrl,
    'model': model,
    'isCloud': isCloud,
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'enableVerboseReasoning': enableVerboseReasoning,
  };

  factory AiModelConfig.fromJson(Map<String, Object?> json) {
    return AiModelConfig(
      providerKind: AiProviderKind.values.firstWhere(
        (kind) => kind.name == json['providerKind'],
        orElse: () => AiProviderKind.openAiCompatible,
      ),
      label: (json['label'] as String?) ?? 'OpenAI-compatible',
      baseUrl: (json['baseUrl'] as String?) ?? 'http://127.0.0.1:11434/v1',
      model: (json['model'] as String?) ?? '',
      isCloud: (json['isCloud'] as bool?) ?? false,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.1,
      maxOutputTokens: (json['maxOutputTokens'] as num?)?.toInt() ?? 600,
      enableVerboseReasoning:
          (json['enableVerboseReasoning'] as bool?) ?? false,
    );
  }

  String encode() => jsonEncode(toJson());
}

enum AiWorkflow { loginFullSequence, orderCashPayment }

enum AiPlanState { needsInput, readyForConfirmation, unsupported }

enum AiItemStrategy { sameForAll, perOrder }

class AiTestPlan {
  const AiTestPlan({
    required this.workflow,
    required this.profileId,
    this.ordersCount = 1,
    this.itemStrategy = AiItemStrategy.sameForAll,
    this.items = const <OrderItem>[],
    this.perIterationItems = const <int, List<OrderItem>>{},
  });

  final AiWorkflow workflow;
  final String profileId;
  final int ordersCount;
  final AiItemStrategy itemStrategy;
  final List<OrderItem> items;
  final Map<int, List<OrderItem>> perIterationItems;

  bool get isOrder => workflow == AiWorkflow.orderCashPayment;

  Iterable<OrderItem> get allItems sync* {
    yield* items;
    for (final orderItems in perIterationItems.values) {
      yield* orderItems;
    }
  }

  AiTestPlan copyWith({String? profileId}) => AiTestPlan(
    workflow: workflow,
    profileId: profileId ?? this.profileId,
    ordersCount: ordersCount,
    itemStrategy: itemStrategy,
    items: items,
    perIterationItems: perIterationItems,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'workflow': workflow.name,
    'profileId': profileId,
    'ordersCount': ordersCount,
    'itemStrategy': itemStrategy.name,
    'items': items.map((item) => item.toJson()).toList(),
    'perIterationItems': perIterationItems.map(
      (key, value) =>
          MapEntry(key.toString(), value.map((item) => item.toJson()).toList()),
    ),
  };

  factory AiTestPlan.fromJson(Map<String, Object?> json) {
    final perIterationItems = _parsePerIterationItems(
      json['perIterationItems'],
    );
    final parsedItems = _parseItems(json['items']);
    final requestedStrategy = AiItemStrategy.values.firstWhere(
      (strategy) => strategy.name == json['itemStrategy'],
      orElse: () => AiItemStrategy.sameForAll,
    );

    return AiTestPlan(
      workflow: AiWorkflow.values.firstWhere(
        (workflow) => workflow.name == json['workflow'],
        orElse: () => AiWorkflow.loginFullSequence,
      ),
      profileId: (json['profileId'] as String?)?.trim() ?? '',
      ordersCount: ((json['ordersCount'] as num?)?.toInt() ?? 1).clamp(1, 50),
      itemStrategy: perIterationItems.isNotEmpty
          ? AiItemStrategy.perOrder
          : requestedStrategy,
      items: parsedItems,
      perIterationItems: perIterationItems,
    );
  }

  static List<OrderItem> _parseItems(Object? raw) {
    final values = raw is List
        ? raw
        : raw is Map
        ? <Object?>[raw]
        : const <Object?>[];
    return values
        .map(_parseItem)
        .whereType<OrderItem>()
        .toList(growable: false);
  }

  static OrderItem? _parseItem(Object? raw) {
    if (raw is Map) {
      return OrderItem.fromJson(raw.cast<String, Object?>());
    }
    // Accept the compact tuple shape occasionally produced by models:
    // [skuCode, type, weight, entryMode]. It is normalized immediately.
    if (raw is List && raw.isNotEmpty) {
      final weight = raw.length > 2 && raw[2] is num
          ? (raw[2] as num).toDouble()
          : double.tryParse(raw.length > 2 ? '${raw[2]}' : '');
      return OrderItem.fromJson(<String, Object?>{
        'skuCode': '${raw.first}',
        if (raw.length > 1) 'type': '${raw[1]}',
        'weight': ?weight,
        if (raw.length > 3) 'entryMode': '${raw[3]}',
      });
    }
    return null;
  }

  static Map<int, List<OrderItem>> _parsePerIterationItems(Object? raw) {
    final result = <int, List<OrderItem>>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final iteration = int.tryParse('${entry.key}');
        if (iteration == null) continue;
        result[iteration] = _parseItems(entry.value);
      }
      return result;
    }
    // Normalize the manual-mode shape: [{"order": 1, "items": [...]}].
    if (raw is List) {
      for (final value in raw.whereType<Map>()) {
        final iteration = int.tryParse(
          '${value['order'] ?? value['iteration'] ?? value['orderNumber'] ?? ''}',
        );
        if (iteration == null) continue;
        result[iteration] = _parseItems(value['items']);
      }
    }
    return result;
  }
}

class AiAssistantResponse {
  const AiAssistantResponse({
    required this.message,
    required this.state,
    this.plan,
    this.missingFields = const <String>[],
  });

  final String message;
  final AiPlanState state;
  final AiTestPlan? plan;
  final List<String> missingFields;

  factory AiAssistantResponse.fromJson(Map<String, Object?> json) {
    final planRaw = json['plan'];
    return AiAssistantResponse(
      message:
          (json['message'] as String?)?.trim() ??
          'I could not create a safe QA plan from that request.',
      state: AiPlanState.values.firstWhere(
        (state) => state.name == json['state'],
        orElse: () => AiPlanState.needsInput,
      ),
      plan: _parsePlan(planRaw),
      missingFields:
          (json['missingFields'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
    );
  }

  static AiTestPlan? _parsePlan(Object? raw) {
    if (raw is Map) return AiTestPlan.fromJson(raw.cast<String, Object?>());
    // Some OpenAI-compatible local models wrap the sole plan in an array.
    if (raw is List) {
      for (final plan in raw.whereType<Map>()) {
        return AiTestPlan.fromJson(plan.cast<String, Object?>());
      }
    }
    return null;
  }
}

enum AiChatRole { user, assistant, system }

// ---------------------------------------------------------------------------
// Planning phases – emitted during AI orchestration so the UI can render a
// step-by-step stepper instead of a blank wait.
// ---------------------------------------------------------------------------

/// Discrete phases the planner goes through before producing a test plan.
enum AiPlanningPhase { parsing, matching, planning, validating, complete }

/// Visible, non-executable diagnostic events from the model-planning layer.
/// They are displayed only in the Assistant UI and never become driver input.
enum AiModelEventKind { status, reasoning, response, error, executionProgress }

class AiModelEvent {
  const AiModelEvent({
    required this.kind,
    required this.message,
    this.phase,
    this.progress,
    this.executionStep,
  });

  final AiModelEventKind kind;
  final String message;

  /// Non-null when [kind] is [AiModelEventKind.status] to indicate which
  /// planning phase is currently active.
  final AiPlanningPhase? phase;

  /// Optional 0.0–1.0 value for progress bar rendering.
  final double? progress;

  /// Non-null when [kind] is [AiModelEventKind.executionProgress].
  final AiExecutionStep? executionStep;
}

typedef AiModelEventCallback = void Function(AiModelEvent event);

// ---------------------------------------------------------------------------
// Execution progress – emitted during test-run so the chat shows live
// scenario completion instead of requiring the user to open the log drawer.
// ---------------------------------------------------------------------------

enum AiScenarioStatus { pending, running, passed, failed, skipped }

class AiExecutionStep {
  const AiExecutionStep({
    required this.scenarioName,
    required this.status,
    this.elapsedMs,
    this.detail,
    this.totalScenarios = 0,
    this.completedScenarios = 0,
  });

  final String scenarioName;
  final AiScenarioStatus status;
  final int? elapsedMs;
  final String? detail;
  final int totalScenarios;
  final int completedScenarios;

  double get progressFraction =>
      totalScenarios > 0 ? completedScenarios / totalScenarios : 0.0;
}

// ---------------------------------------------------------------------------
// Rich content – allows assistant messages to carry structured cards / tables
// rather than just plain text.
// ---------------------------------------------------------------------------

/// Base class for rich content attached to an [AiChatMessage].
sealed class AiRichContent {
  const AiRichContent();
}

/// A styled summary card showing the planned test profile, workflow, and
/// scenario list – rendered as a card + table in the chat.
class AiRichPlanSummary extends AiRichContent {
  const AiRichPlanSummary({
    required this.profileLabel,
    required this.workflowLabel,
    required this.scenarios,
  });

  final String profileLabel;
  final String workflowLabel;
  final List<AiScenarioRow> scenarios;
}

class AiScenarioRow {
  const AiScenarioRow({required this.name, this.status = 'Pending'});

  final String name;
  final String status;
}

/// A pass/fail test-execution report card with scenario-level results, timing,
/// and totals – rendered as a rich table in the chat.
class AiRichTestReport extends AiRichContent {
  const AiRichTestReport({
    required this.suiteTitle,
    required this.profileLabel,
    required this.passed,
    required this.totalDurationMs,
    required this.scenarioResults,
  });

  final String suiteTitle;
  final String profileLabel;
  final bool passed;
  final int totalDurationMs;
  final List<AiScenarioResult> scenarioResults;

  int get passedCount => scenarioResults.where((s) => s.passed).length;
  int get failedCount => scenarioResults.where((s) => !s.passed).length;
}

/// Per-order outcomes for an order suite. These are kept separate from the
/// suite checks so a two-order request visibly produces two order results.
class AiRichOrderReport extends AiRichContent {
  const AiRichOrderReport({
    required this.suiteTitle,
    required this.profileLabel,
    required this.passed,
    required this.totalDurationMs,
    required this.orders,
    required this.testChecks,
  });

  final String suiteTitle;
  final String profileLabel;
  final bool passed;
  final int totalDurationMs;
  final List<AiOrderResult> orders;
  final List<AiScenarioResult> testChecks;

  int get passedCount => orders.where((order) => order.passed).length;
}

class AiOrderResult {
  const AiOrderResult({
    required this.orderNumber,
    required this.itemSummary,
    required this.passed,
    required this.durationMs,
    required this.cashAmount,
  });

  final int orderNumber;
  final String itemSummary;
  final bool passed;
  final int durationMs;
  final int cashAmount;
}

/// A compact, user-safe record of how the application prepared a request.
/// This intentionally contains only application status steps, never model
/// reasoning or hidden instructions.
class AiRichPlanningSummary extends AiRichContent {
  const AiRichPlanningSummary({required this.steps});

  final List<String> steps;
}

class AiScenarioResult {
  const AiScenarioResult({
    required this.name,
    required this.passed,
    required this.durationMs,
    this.detail,
  });

  final String name;
  final bool passed;
  final int durationMs;
  final String? detail;
}

// ---------------------------------------------------------------------------
// Chat message – now includes an optional [richContent] for structured
// rendering in the message list.
// ---------------------------------------------------------------------------

class AiChatMessage {
  AiChatMessage({
    required this.role,
    required this.text,
    this.richContent,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final AiChatRole role;
  final String text;
  final DateTime at;

  /// When non-null, the message list renders a structured card/table instead
  /// of plain [SelectableText].
  final AiRichContent? richContent;
}
