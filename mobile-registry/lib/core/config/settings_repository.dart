import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_validators.dart';

/// Persistência das configurações em `shared_preferences`
/// (dados não sensíveis; o token ficará no armazenamento seguro, na US-04).
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String hostKey = 'settings.host';
  static const String portKey = 'settings.port';
  static const String maxPhotoKbKey = 'settings.maxPhotoKb';
  static const String faceSamplesKey = 'settings.faceSamples';

  /// Lê as configurações. Valor ausente ou inválido volta ao padrão do campo.
  AppSettings load() {
    final host = _prefs.getString(hostKey);
    final port = _prefs.getInt(portKey);
    final photo = _prefs.getInt(maxPhotoKbKey);
    final samples = _prefs.getInt(faceSamplesKey);

    return AppSettings(
      host: host != null && SettingsValidators.host(host) == null
          ? host
          : AppSettings.defaultHost,
      port: port != null && SettingsValidators.port('$port') == null
          ? port
          : AppSettings.defaultPort,
      maxPhotoKb: photo != null && SettingsValidators.photoKb('$photo') == null
          ? photo
          : AppSettings.defaultMaxPhotoKb,
      faceSamples: SettingsValidators.faceSamples(samples) == null
          ? samples!
          : AppSettings.defaultFaceSamples,
    );
  }

  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(hostKey, settings.host),
      _prefs.setInt(portKey, settings.port),
      _prefs.setInt(maxPhotoKbKey, settings.maxPhotoKb),
      _prefs.setInt(faceSamplesKey, settings.faceSamples),
    ]);
  }
}
