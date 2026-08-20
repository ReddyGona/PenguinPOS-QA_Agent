import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/unified_execution_service.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';

void main() {
  group('UnifiedExecutionService with SSH Target', () {
    late QaCredentialVault vault;
    late UnifiedExecutionService service;

    setUp(() {
      vault = QaCredentialVault();
      service = UnifiedExecutionService(credentialVault: vault);
    });

    test(
      'prepareExecution succeeds for valid SSH configuration without checking local paths',
      () async {
        await vault.write(
          'kpn-dev',
          const QaStoredCredentials(
            loginId: '8888888888',
            password: 'password123',
            unlockPin: '1234',
          ),
        );

        const sshConfig = QaSshConfig(
          host: '10.3.10.210',
          username: 'savo',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
        );

        final prepared = await service.prepareExecution(
          plan: const ExecutionPlan(
            profileId: 'kpn-dev',
            suiteId: QaSuiteId.loginTerminal,
          ),
          profile: QaProfile.values.firstWhere((p) => p.id == 'kpn-dev'),
          targetMode: QaTargetMode.ssh,
          sshConfig: sshConfig,
        );

        expect(prepared.targetMode, QaTargetMode.ssh);
        expect(prepared.sshConfig, isNotNull);
        expect(prepared.sshConfig!.host, '10.3.10.210');
        expect(prepared.appRoot, '/home/savo/Documents/penguin_pos');
        expect(prepared.credentials.loginId, '8888888888');
        expect(prepared.credentials.password, 'password123');
      },
    );

    test(
      'prepareExecution fails when targetMode is ssh but sshConfig is null',
      () async {
        await vault.write(
          'kpn-dev',
          const QaStoredCredentials(
            loginId: '8888888888',
            password: 'password123',
          ),
        );

        expect(
          () => service.prepareExecution(
            plan: const ExecutionPlan(
              profileId: 'kpn-dev',
              suiteId: QaSuiteId.loginTerminal,
            ),
            profile: QaProfile.values.firstWhere((p) => p.id == 'kpn-dev'),
            targetMode: QaTargetMode.ssh,
            sshConfig: null,
          ),
          throwsA(isA<PreflightValidationException>()),
        );
      },
    );
  });
}
