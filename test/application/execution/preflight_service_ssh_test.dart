import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/preflight_service.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

void main() {
  group('PreflightService with SSH readiness', () {
    final kpnDevProfile = QaProfile.values.firstWhere((p) => p.id == 'kpn-dev');

    test('preflight passes when sshTargetReachable is true', () async {
      final preflight = PreflightService(
        PreflightDependencies(
          findProfile: (id) => PreflightProfile(
            id: kpnDevProfile.id,
            label: kpnDevProfile.label,
            isProduction: false,
          ),
          hasSavedLoginCredentials: (_) => true,
          isSuiteImplemented: (_) => true,
          checkRuntimeReadiness: () => const RuntimeReadiness(
            localExecutionSupported: false,
            appRootIsValid: false,
            flutterExecutableIsValid: false,
            sshTargetReachable: true,
          ),
        ),
      );

      final plan = ExecutionPlan(
        profileId: kpnDevProfile.id,
        suiteId: QaSuiteId.loginTerminal,
      );
      final result = await preflight.check(plan);

      expect(result.passed, isTrue);
      expect(
        result.checks.any(
          (c) =>
              c.kind == PreflightCheckKind.runtime &&
              c.status == PreflightCheckStatus.passed &&
              c.message.contains('remote SSH target is reachable'),
        ),
        isTrue,
      );
    });

    test('preflight fails when sshTargetReachable is false', () async {
      final preflight = PreflightService(
        PreflightDependencies(
          findProfile: (id) => PreflightProfile(
            id: kpnDevProfile.id,
            label: kpnDevProfile.label,
            isProduction: false,
          ),
          hasSavedLoginCredentials: (_) => true,
          isSuiteImplemented: (_) => true,
          checkRuntimeReadiness: () => const RuntimeReadiness(
            localExecutionSupported: false,
            appRootIsValid: false,
            flutterExecutableIsValid: false,
            sshTargetReachable: false,
          ),
        ),
      );

      final plan = ExecutionPlan(
        profileId: kpnDevProfile.id,
        suiteId: QaSuiteId.loginTerminal,
      );
      final result = await preflight.check(plan);

      expect(result.passed, isFalse);
      expect(
        result.checks.any(
          (c) =>
              c.kind == PreflightCheckKind.runtime &&
              c.status == PreflightCheckStatus.failed &&
              c.message.contains('remote SSH target is not reachable'),
        ),
        isTrue,
      );
    });
  });
}
