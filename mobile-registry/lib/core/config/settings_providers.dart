import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

/// Sobrescrito no `main()` com a instância já carregada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Sobrescreva sharedPreferencesProvider no ProviderScope.',
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Estado global das configurações. O cliente HTTP lê daqui a cada requisição,
/// então uma alteração vale imediatamente, sem reiniciar o app.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    state = settings;
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
