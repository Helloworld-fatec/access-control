import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de configuração do Terminal de Acesso (US-02 e US-03).
class TerminalConfig {
  final String? serverAddress;
  final String terminalId;
  final String apiKey;
  final int inactivityTimeoutSeconds;
  final bool voiceAccessibilityEnabled;

  const TerminalConfig({
    this.serverAddress,
    this.terminalId = '',
    this.apiKey = '',
    this.inactivityTimeoutSeconds = 30,
    this.voiceAccessibilityEnabled = true,
  });

  bool get isConfigured =>
      serverAddress != null && apiKey.isNotEmpty && terminalId.isNotEmpty;

  static final terminalIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String? validateTerminalKey(String? value) {
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Informe uma chave de seis caracteres hexadecimais.';
  }

  static String? normalizeServerAddress(String value) {
    final input = value.trim();
    final hasScheme = input.contains('://');
    final match = RegExp(
      r'^(https?)://(\[[0-9a-f:.]+\]|[a-z0-9.-]+)(?::([0-9]+))?(?:/api)*/*$',
      caseSensitive: false,
    ).firstMatch(hasScheme ? input : 'http://$input');
    if (match == null) return null;

    final scheme = match[1]!.toLowerCase();
    final host = match[2]!.toLowerCase();
    final portText = match[3];
    final port = portText == null ? null : int.tryParse(portText);
    if ((!hasScheme && portText == null) ||
        (portText != null && (port == null || port < 1 || port > 65535))) {
      return null;
    }

    if (host.startsWith('[')) {
      try {
        Uri.parse('$scheme://$host/api');
      } on FormatException {
        return null;
      }
    } else {
      final labels = host.replaceFirst(RegExp(r'\.$'), '').split('.');
      final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');
      if (host.length > 254 ||
          labels.any((label) => !labelPattern.hasMatch(label))) {
        return null;
      }
      if (labels.length > 1 &&
          labels.every((label) => int.tryParse(label) != null) &&
          (labels.length != 4 ||
              labels.any((label) => int.parse(label) > 255))) {
        return null;
      }
    }

    final authority = port == null ? host : '$host:$port';
    return '$scheme://$authority/api';
  }

  String get backendBaseUrl => serverAddress ?? '';

  TerminalConfig copyWith(
      {String? serverAddress, String? terminalId, String? apiKey}) {
    return TerminalConfig(
      serverAddress: serverAddress ?? this.serverAddress,
      terminalId: terminalId ?? this.terminalId,
      apiKey: apiKey ?? this.apiKey,
      inactivityTimeoutSeconds: inactivityTimeoutSeconds,
      voiceAccessibilityEnabled: voiceAccessibilityEnabled,
    );
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
  static const _kInactivitySeconds = 'terminal_inactivity_seconds';
  static const _kVoiceAccessibility = 'terminal_voice_accessibility';

  static const _kLegacyApiKey = 'terminal_api_key';
  static const _kConnection = 'terminal_verified_connection';

  final FlutterSecureStorage _secureStorage;

  const LocalConfigStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<TerminalConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? connection;
    try {
      final stored = await _secureStorage
          .read(key: _kConnection)
          .timeout(const Duration(seconds: 2));
      if (stored != null) {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic> &&
            decoded['address'] is String &&
            TerminalConfig.normalizeServerAddress(
                  decoded['address'] as String,
                ) !=
                null &&
            decoded['key'] is String &&
            TerminalConfig.validateTerminalKey(decoded['key'] as String) ==
                null &&
            decoded['id'] is String &&
            TerminalConfig.terminalIdPattern.hasMatch(
              decoded['id'] as String,
            )) {
          connection = decoded;
        }
      }
    } catch (_) {}
    const defaults = TerminalConfig();
    return TerminalConfig(
      serverAddress:
          connection?['address'] as String? ?? _legacyServerAddress(prefs),
      terminalId: connection?['id'] as String? ?? '',
      apiKey: connection?['key'] as String? ?? '',
      inactivityTimeoutSeconds: prefs.getInt(_kInactivitySeconds) ??
          defaults.inactivityTimeoutSeconds,
      voiceAccessibilityEnabled: prefs.getBool(_kVoiceAccessibility) ??
          defaults.voiceAccessibilityEnabled,
    );
  }

  String? _legacyServerAddress(SharedPreferences prefs) {
    final host = prefs.getString(_kBackendHost);
    if (host == null) return null;
    final scheme = prefs.getBool(_kUseHttps) == true ? 'https' : 'http';
    final port = prefs.getInt(_kBackendPort) ?? 3000;
    return TerminalConfig.normalizeServerAddress('$scheme://$host:$port');
  }

  @override
  Future<void> save(TerminalConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyApiKey);
    await _secureStorage.write(
      key: _kConnection,
      value: jsonEncode({
        'address': config.serverAddress,
        'key': config.apiKey,
        'id': config.terminalId,
      }),
    );
  }
}
