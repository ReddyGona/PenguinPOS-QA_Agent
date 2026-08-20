import 'package:penguin_pos_qa_agent/application/execution/qa_execution_coordinator.dart';
import 'package:penguin_pos_qa_agent/application/execution/test_run_command_mapper.dart';
import 'package:penguin_pos_qa_agent/application/execution/unified_execution_service.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_run_command.dart';

/// Interface used by CLI/MCP transports, keeping them testable and independent
/// from the execution service's concrete process/driver implementation.
abstract interface class TestRunCommandExecutor {
  Future<ExecutionPlanResult> executeCommand(
    TestRunCommand command, {
    String? appRoot,
    String? flutterExecutable,
    QaTargetMode targetMode = QaTargetMode.local,
    QaSshConfig? sshConfig,
  });
}

/// The common JSON-first execution endpoint for non-GUI surfaces.
class UnifiedTestRunCommandExecutor implements TestRunCommandExecutor {
  UnifiedTestRunCommandExecutor({
    UnifiedExecutionService? service,
    List<QaProfile> profiles = QaProfile.values,
    TestRunCommandMapper? mapper,
  }) : _service = service ?? UnifiedExecutionService(),
       _profiles = profiles,
       _mapper = mapper ?? TestRunCommandMapper();

  final UnifiedExecutionService _service;
  final List<QaProfile> _profiles;
  final TestRunCommandMapper _mapper;

  @override
  Future<ExecutionPlanResult> executeCommand(
    TestRunCommand command, {
    String? appRoot,
    String? flutterExecutable,
    QaTargetMode targetMode = QaTargetMode.local,
    QaSshConfig? sshConfig,
  }) async {
    final plan = _mapper.map(command);
    final profile = _findProfile(command.profileId);
    if (profile == null) {
      throw FormatException('Unknown QA profile "${command.profileId}".');
    }
    final prepared = await _service.prepareExecution(
      plan: plan,
      profile: profile,
      appRoot: appRoot,
      flutterExecutable: flutterExecutable,
      targetMode: targetMode,
      sshConfig: sshConfig,
    );
    return _service.execute(prepared);
  }

  QaProfile? _findProfile(String requestedId) {
    final normalized = requestedId.trim().toLowerCase();
    for (final profile in _profiles) {
      if (profile.id.toLowerCase() == normalized ||
          profile.aliases.any((alias) => alias.toLowerCase() == normalized)) {
        return profile;
      }
    }
    return null;
  }
}
