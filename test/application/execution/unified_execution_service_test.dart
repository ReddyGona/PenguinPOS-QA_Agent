import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/application/execution/preflight_service.dart';
import 'package:penguin_pos_qa_agent/application/execution/unified_execution_service.dart';
import 'package:penguin_pos_qa_agent/domain/plan/execution_plan.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_credential_vault.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';

class _FakeCredentialVault extends QaCredentialVault {
  _FakeCredentialVault(this._credentials);
  final Map<String, QaStoredCredentials> _credentials;

  @override
  Future<QaStoredCredentials> read(String profileId) async {
    return _credentials[profileId] ??
        const QaStoredCredentials(loginId: '', password: '');
  }

  @override
  Future<void> write(String profileId, QaStoredCredentials credentials) async {
    _credentials[profileId] = credentials;
  }

  @override
  Future<String> readAiApiKey() async => '';

  @override
  Future<void> writeAiApiKey(String apiKey) async {}
}

void main() {
  group('UnifiedExecutionService Tests', () {
    test('strictly blocks production targets at preflight stage', () async {
      final vault = _FakeCredentialVault({
        'prod_store': const QaStoredCredentials(
          loginId: 'admin',
          password: 'secretPassword',
        ),
      });

      final service = UnifiedExecutionService(credentialVault: vault);

      const prodProfile = QaProfile(
        id: 'prod_store',
        label: 'Production Store',
        entity: '100',
        environment: 'production',
      );

      const plan = ExecutionPlan(
        suiteId: QaSuiteId.loginTerminal,
        profileId: 'prod_store',
      );

      expect(
        () => service.prepareExecution(plan: plan, profile: prodProfile),
        throwsA(
          isA<PreflightValidationException>().having(
            (e) => e.kind,
            'kind',
            PreflightCheckKind.nonProductionTarget,
          ),
        ),
      );
    });

    test('blocks missing credentials at preflight stage', () async {
      final vault = _FakeCredentialVault({});
      final service = UnifiedExecutionService(credentialVault: vault);

      const qaProfile = QaProfile(
        id: 'qa_staging',
        label: 'QA Staging',
        entity: '100',
        environment: 'staging',
      );

      const plan = ExecutionPlan(
        suiteId: QaSuiteId.loginTerminal,
        profileId: 'qa_staging',
      );

      expect(
        () => service.prepareExecution(plan: plan, profile: qaProfile),
        throwsA(
          isA<PreflightValidationException>().having(
            (e) => e.kind,
            'kind',
            PreflightCheckKind.credentials,
          ),
        ),
      );
    });
  });
}
