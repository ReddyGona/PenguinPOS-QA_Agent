import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/unified_execution_service.dart';
import 'package:penguin_pos_qa_agent/automation/core/telemetry/api_trace_event.dart';
import 'package:penguin_pos_qa_agent/automation/execution_event.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// State Controller managing QA execution lifecycle, telemetry buffers, and activity streams.
///
/// Decouples execution orchestration from the presentation widgets.
class DashboardStateController extends ChangeNotifier {
  DashboardStateController({UnifiedExecutionService? executionService})
    : _executionService = executionService ?? UnifiedExecutionService();

  final UnifiedExecutionService _executionService;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _stopRequested = false;
  bool get stopRequested => _stopRequested;

  ExecutionPlanResult? _lastResult;
  ExecutionPlanResult? get lastResult => _lastResult;

  final List<QaActivityMessage> _activityLogs = [];
  List<QaActivityMessage> get activityLogs => List.unmodifiable(_activityLogs);

  final List<ApiTraceEvent> _apiTraces = [];
  List<ApiTraceEvent> get apiTraces => List.unmodifiable(_apiTraces);

  final List<String> _completedScenarios = [];
  List<String> get completedScenarios => List.unmodifiable(_completedScenarios);

  void addActivityLog(String title, String message, QaActivityKind kind) {
    _activityLogs.add(
      QaActivityMessage(title, message, kind, at: DateTime.now()),
    );
    notifyListeners();
  }

  void addApiTraces(List<ApiTraceEvent> traces) {
    if (traces.isEmpty) return;
    _apiTraces.addAll(traces);
    notifyListeners();
  }

  void clearLogs() {
    _activityLogs.clear();
    _apiTraces.clear();
    _completedScenarios.clear();
    notifyListeners();
  }

  /// Runs a preflight-validated execution plan.
  Future<ExecutionPlanResult> runExecutionPlan({
    required ExecutionPlan plan,
    required QaProfile profile,
    String? appRoot,
    String? flutterPath,
    void Function(ExecutionEvent event)? onEvent,
    void Function(String scenarioName)? onScenarioCompleted,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (_isRunning) {
      throw StateError('A QA execution is already running.');
    }

    _isRunning = true;
    _stopRequested = false;
    clearLogs();
    notifyListeners();

    try {
      final prepared = await _executionService.prepareExecution(
        plan: plan,
        profile: profile,
        appRoot: appRoot,
        flutterExecutable: flutterPath,
      );

      final result = await _executionService.execute(
        prepared,
        callbacks: ExecutionCallbacks(
          onEvent: (event) {
            addActivityLog(event.title, event.message, QaActivityKind.info);
            onEvent?.call(event);
          },
          onScenarioCompleted: (scenario) {
            if (!_completedScenarios.contains(scenario)) {
              _completedScenarios.add(scenario);
              notifyListeners();
            }
            onScenarioCompleted?.call(scenario);
          },
          onOrderProgress: onProgress,
        ),
      );

      _lastResult = result;
      return result;
    } catch (e) {
      addActivityLog('Execution Error', e.toString(), QaActivityKind.error);
      rethrow;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Requests stopping the active execution.
  Future<void> requestStop() async {
    if (!_isRunning || _stopRequested) return;
    _stopRequested = true;
    notifyListeners();
    await _executionService.requestStop();
  }
}
