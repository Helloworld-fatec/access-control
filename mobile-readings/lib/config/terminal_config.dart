import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de configuração do Terminal de Acesso (US-02 e US-03).
class TerminalConfig {
  final String backendHost;
  final int backendPort;
  final bool useHttps;
  final String mqttHost;
  final int mqttPort;
  final String mqttUsername;
  final String mqttPassword;
  final String terminalId;
  final String apiKey;
  final int inactivityTimeoutSeconds;
  final double faceSimilarityThreshold;
  final bool simulationMode;
  final bool voiceAccessibilityEnabled;
  final bool kioskModeEnabled;
  final bool preferFaceAuth;

  const TerminalConfig({
    this.backendHost = '192.168.15.25',
    this.backendPort = 3000,
    this.useHttps = false,
    this.mqttHost = '192.168.15.25',
    this.mqttPort = 1883,
    this.mqttUsername = '',
    this.mqttPassword = '',
    this.terminalId = '633a2270-08c0-45dc-8e55-d9a6bc5c802d',
    this.apiKey = 'terminal-key-secreta-2026-fatec',
    this.inactivityTimeoutSeconds = 30,
    this.faceSimilarityThreshold = 0.75,
    this.simulationMode = false,
    this.voiceAccessibilityEnabled = true,
    this.kioskModeEnabled = true,
    this.preferFaceAuth = false,
  });

  /// URL base da API do backend (já com prefixo /api).
  String get backendBaseUrl {
    final scheme = useHttps ? 'https' : 'http';
    return '$scheme://$backendHost:$backendPort/api';
  }

  /// Tópico MQTT oficial de presença assinado pelo terminal (docs/contrato-mqtt.md).
  String get mqttPresenceTopic => 'access/v1/terminals/$terminalId/presence';

  /// Tópico MQTT legado de presença (retrocompatibilidade).
  String get mqttPresenceLegacyTopic => 'terminal/$terminalId/presence';

  /// Tópico MQTT oficial de decisão/resultado de acesso (docs/contrato-mqtt.md).
  String get mqttDecisionTopic =>
      'access/v1/terminals/$terminalId/access/decision';

  /// Tópico MQTT legado de resultado de acesso (retrocompatibilidade).
  String get mqttResultLegacyTopic => 'terminal/$terminalId/result';

  /// Tópico MQTT para sinalização de gravação remota de tag NFC (US-10).
  String get mqttNfcWritingTopic => 'access/v1/terminals/$terminalId/nfc/writing';

  /// Tópico MQTT legado de gravação remota de tag NFC (US-10).
  String get mqttNfcWritingLegacyTopic => 'terminal/$terminalId/nfc/writing';

  TerminalConfig copyWith({
    String? backendHost,
    int? backendPort,
    bool? useHttps,
    String? mqttHost,
    int? mqttPort,
    String? mqttUsername,
    String? mqttPassword,
    String? terminalId,
    String? apiKey,
    int? inactivityTimeoutSeconds,
    double? faceSimilarityThreshold,
    bool? simulationMode,
    bool? voiceAccessibilityEnabled,
    bool? kioskModeEnabled,
    bool? preferFaceAuth,
  }) {
    return TerminalConfig(
      backendHost: backendHost ?? this.backendHost,
      backendPort: backendPort ?? this.backendPort,
      useHttps: useHttps ?? this.useHttps,
      mqttHost: mqttHost ?? this.mqttHost,
      mqttPort: mqttPort ?? this.mqttPort,
      mqttUsername: mqttUsername ?? this.mqttUsername,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      terminalId: terminalId ?? this.terminalId,
      apiKey: apiKey ?? this.apiKey,
      inactivityTimeoutSeconds:
          inactivityTimeoutSeconds ?? this.inactivityTimeoutSeconds,
      faceSimilarityThreshold:
          faceSimilarityThreshold ?? this.faceSimilarityThreshold,
      simulationMode: simulationMode ?? this.simulationMode,
      voiceAccessibilityEnabled:
          voiceAccessibilityEnabled ?? this.voiceAccessibilityEnabled,
      kioskModeEnabled: kioskModeEnabled ?? this.kioskModeEnabled,
      preferFaceAuth: preferFaceAuth ?? this.preferFaceAuth,
    );
  }

  /// Valida endereço IP ou hostname (US-02).
  static String? validateHost(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe o endereço IP ou domínio.';
    }
    if (trimmed.contains(' ') || trimmed.contains('://') || trimmed.contains('/')) {
      return 'Informe apenas o IP ou domínio (sem http:// ou barras).';
    }
    final hostRegex = RegExp(r'^[a-zA-Z0-9.-]+$');
    if (!hostRegex.hasMatch(trimmed)) {
      return 'Formato de endereço inválido.';
    }
    return null;
  }

  /// Valida número de porta TCP (1 a 65535) (US-02).
  static String? validatePort(String? value) {
    final trimmed = value?.trim() ?? '';
    final port = int.tryParse(trimmed);
    if (port == null || port < 1 || port > 65535) {
      return 'Informe uma porta válida entre 1 e 65535.';
    }
    return null;
  }

  /// Valida identificador do terminal (US-02).
  static String? validateTerminalId(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Informe o identificador do terminal.';
    }
    return null;
  }

  /// Valida tempo de inatividade em segundos (US-02, US-13).
  static String? validateInactivitySeconds(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    if (seconds == null || seconds < 5 || seconds > 600) {
      return 'Informe um tempo entre 5 e 600 segundos.';
    }
    return null;
  }

  /// Valida limiar de similaridade facial (0.1 a 1.0) (US-02).
  static String? validateFaceThreshold(String? value) {
    final normalized = (value ?? '').trim().replaceAll(',', '.');
    final threshold = double.tryParse(normalized);
    if (threshold == null || threshold < 0.1 || threshold > 1.0) {
      return 'Informe um limiar entre 0.10 e 1.00.';
    }
    return null;
  }
}

/// Interface de persistência para permitir testes unitários sem canais nativos.
abstract class ConfigStorage {
  Future<TerminalConfig> load();
  Future<void> save(TerminalConfig config);
}

/// Implementação padrão usando shared_preferences e flutter_secure_storage (US-02, US-03).
class LocalConfigStorage implements ConfigStorage {
  static const _kBackendHost = 'terminal_backend_host';
  static const _kBackendPort = 'terminal_backend_port';
  static const _kUseHttps = 'terminal_use_https';
  static const _kMqttHost = 'terminal_mqtt_host';
  static const _kMqttPort = 'terminal_mqtt_port';
  static const _kMqttUsername = 'terminal_mqtt_username';
  static const _kTerminalId = 'terminal_id';
  static const _kInactivitySeconds = 'terminal_inactivity_seconds';
  static const _kFaceThreshold = 'terminal_face_threshold';
  static const _kSimulationMode = 'terminal_simulation_mode';
  static const _kVoiceAccessibility = 'terminal_voice_accessibility';
  static const _kKioskMode = 'terminal_kiosk_mode';
  static const _kPreferFaceAuth = 'terminal_prefer_face_auth';

  static const _kSecureApiKey = 'terminal_api_key';
  static const _kSecureMqttPassword = 'terminal_mqtt_password';

  final FlutterSecureStorage _secureStorage;

  const LocalConfigStorage({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<TerminalConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = '';
    String mqttPassword = '';
    try {
      apiKey = await _secureStorage.read(key: _kSecureApiKey) ?? '';
      mqttPassword = await _secureStorage.read(key: _kSecureMqttPassword) ?? '';
    } catch (_) {
      // Fallback caso o ambiente desktop/web de desenvolvimento não suporte keystore nativo
      apiKey = prefs.getString(_kSecureApiKey) ?? '';
      mqttPassword = prefs.getString(_kSecureMqttPassword) ?? '';
    }

    const defaults = TerminalConfig();
    return TerminalConfig(
      backendHost: prefs.getString(_kBackendHost) ?? defaults.backendHost,
      backendPort: prefs.getInt(_kBackendPort) ?? defaults.backendPort,
      useHttps: prefs.getBool(_kUseHttps) ?? defaults.useHttps,
      mqttHost: prefs.getString(_kMqttHost) ?? defaults.mqttHost,
      mqttPort: prefs.getInt(_kMqttPort) ?? defaults.mqttPort,
      mqttUsername: prefs.getString(_kMqttUsername) ?? defaults.mqttUsername,
      mqttPassword: mqttPassword,
      terminalId: prefs.getString(_kTerminalId) ?? defaults.terminalId,
      apiKey: apiKey.isNotEmpty ? apiKey : defaults.apiKey,
      inactivityTimeoutSeconds:
          prefs.getInt(_kInactivitySeconds) ?? defaults.inactivityTimeoutSeconds,
      faceSimilarityThreshold:
          prefs.getDouble(_kFaceThreshold) ?? defaults.faceSimilarityThreshold,
      simulationMode:
          prefs.getBool(_kSimulationMode) ?? defaults.simulationMode,
      voiceAccessibilityEnabled:
          prefs.getBool(_kVoiceAccessibility) ?? defaults.voiceAccessibilityEnabled,
      kioskModeEnabled:
          prefs.getBool(_kKioskMode) ?? defaults.kioskModeEnabled,
      preferFaceAuth:
          prefs.getBool(_kPreferFaceAuth) ?? defaults.preferFaceAuth,
    );
  }

  @override
  Future<void> save(TerminalConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendHost, config.backendHost.trim());
    await prefs.setInt(_kBackendPort, config.backendPort);
    await prefs.setBool(_kUseHttps, config.useHttps);
    await prefs.setString(_kMqttHost, config.mqttHost.trim());
    await prefs.setInt(_kMqttPort, config.mqttPort);
    await prefs.setString(_kMqttUsername, config.mqttUsername.trim());
    await prefs.setString(_kTerminalId, config.terminalId.trim());
    await prefs.setInt(_kInactivitySeconds, config.inactivityTimeoutSeconds);
    await prefs.setDouble(_kFaceThreshold, config.faceSimilarityThreshold);
    await prefs.setBool(_kSimulationMode, config.simulationMode);
    await prefs.setBool(_kVoiceAccessibility, config.voiceAccessibilityEnabled);
    await prefs.setBool(_kKioskMode, config.kioskModeEnabled);
    await prefs.setBool(_kPreferFaceAuth, config.preferFaceAuth);

    try {
      await _secureStorage.write(
        key: _kSecureApiKey,
        value: config.apiKey.trim(),
      );
      await _secureStorage.write(
        key: _kSecureMqttPassword,
        value: config.mqttPassword,
      );
    } catch (_) {
      await prefs.setString(_kSecureApiKey, config.apiKey.trim());
      await prefs.setString(_kSecureMqttPassword, config.mqttPassword);
    }
  }
}
