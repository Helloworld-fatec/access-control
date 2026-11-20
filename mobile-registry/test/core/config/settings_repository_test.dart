import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/config/app_settings.dart';
import 'package:mobile_registry/core/config/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsRepository> repoWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  test('sem nada salvo, devolve os padrões (50 KB, 3 capturas)', () async {
    final repo = await repoWith({});
    final s = repo.load();
    expect(s, AppSettings.defaults);
    expect(s.maxPhotoKb, 50);
    expect(s.faceSamples, 3);
    expect(s.baseUrl, 'http://10.0.2.2:3000/api');
  });

  test('salva e lê de volta', () async {
    final repo = await repoWith({});
    const novo = AppSettings(
      host: '192.168.0.10',
      port: 8080,
      maxPhotoKb: 80,
      faceSamples: 5,
    );
    await repo.save(novo);
    expect(repo.load(), novo);
    expect(novo.baseUrl, 'http://192.168.0.10:8080/api');
    expect(novo.maxPhotoBytes, 80 * 1024);
  });

  test('valores corrompidos voltam ao padrão do campo', () async {
    final repo = await repoWith({
      SettingsRepository.hostKey: 'servidor-invalido',
      SettingsRepository.portKey: 99999,
      SettingsRepository.maxPhotoKbKey: 5000,
      SettingsRepository.faceSamplesKey: 9,
    });
    expect(repo.load(), AppSettings.defaults);
  });

  test('mantém campos válidos e troca só os inválidos', () async {
    final repo = await repoWith({
      SettingsRepository.hostKey: '172.16.0.5',
      SettingsRepository.portKey: 0,
    });
    final s = repo.load();
    expect(s.host, '172.16.0.5');
    expect(s.port, AppSettings.defaultPort);
  });
}
