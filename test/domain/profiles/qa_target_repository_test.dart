import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_ssh_config.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/repository/qa_target_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QaTargetPreferencesRepository', () {
    late QaTargetPreferencesRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      repository = QaTargetPreferencesRepository();
    });

    test(
      'scopes target mode and SSH config per profile with fallback',
      () async {
        // Global defaults
        await repository.saveTargetMode(QaTargetMode.local);
        expect(await repository.loadTargetMode('kpn-dev'), QaTargetMode.local);

        // Save profile-scoped config for kpn-dev
        const kpnConfig = QaSshConfig(
          host: '10.3.10.210',
          username: 'savo',
          remoteAppRoot: '/home/savo/Documents/penguin_pos',
        );
        await repository.saveTargetMode('kpn-dev', QaTargetMode.ssh);
        await repository.saveSshConfig('kpn-dev', kpnConfig);

        // Verify kpn-dev gets SSH mode and config
        expect(await repository.loadTargetMode('kpn-dev'), QaTargetMode.ssh);
        final loadedKpn = await repository.loadSshConfig('kpn-dev');
        expect(loadedKpn?.host, '10.3.10.210');
        expect(loadedKpn?.username, 'savo');

        // Verify another profile (ibo-dev) falls back cleanly
        await repository.saveTargetMode('ibo-dev', QaTargetMode.local);
        expect(await repository.loadTargetMode('ibo-dev'), QaTargetMode.local);
      },
    );
  });
}
