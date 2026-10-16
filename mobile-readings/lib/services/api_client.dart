import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/terminal_config.dart';
import '../models/access_result.dart';
import '../models/qr_token.dart';
import '../models/terminal_status.dart';

/// Exceção da camada de API do terminal.
class TerminalApiException implements Exception {
  final String message;
  final int? statusCode;

  const TerminalApiException(this.message, {this.statusCode});

  @override
  String toString() => 'TerminalApiException($statusCode): $message';
}

/// Camada única de acesso HTTP do Terminal de Acesso (US-03, US-12).
/// Inclui autenticação por chave do terminal, retry automático em falhas de rede
/// e comportamento fail-closed (nunca libera acesso sem resposta do backend).
class TerminalApiClient {
  TerminalConfig _config;
  final http.Client _httpClient;
  final int maxRetries;
  final Duration requestTimeout;
  final Duration retryDelay;

  TerminalApiClient({
    required TerminalConfig config,
    http.Client? httpClient,
    this.maxRetries = 3,
    this.requestTimeout = const Duration(seconds: 4),
    this.retryDelay = const Duration(milliseconds: 350),
  })  : _config = config,
        _httpClient = httpClient ?? http.Client();

  TerminalConfig get config => _config;

  void updateConfig(TerminalConfig newConfig) {
    _config = newConfig;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final key = _config.apiKey.trim();
    if (key.isNotEmpty) {
      headers['x-api-key'] = key;
      headers['Authorization'] = 'Bearer $key';
    }
    return headers;
  }

  Uri _buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${_config.backendBaseUrl}$cleanPath');
  }

  /// Executa chamada HTTP com retry automático em falhas de rede/timeout (US-03).
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() requestFn,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await requestFn().timeout(requestTimeout);
        // Erros 5xx de servidor também sofrem retry; 2xx/4xx retornam direto
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future<void>.delayed(retryDelay * attempt);
          continue;
        }
        return response;
      } catch (err) {
        lastError = err;
        if (attempt < maxRetries) {
          await Future<void>.delayed(retryDelay * attempt);
        }
      }
    }
    throw TerminalApiException(
      'Sem conexão com o servidor após $maxRetries tentativas ($lastError).',
    );
  }

  /// Obtém o QR Code rotativo em GET /terminals/{id}/qr (US-07, US-08).
  Future<QrToken> fetchQrToken({DateTime? now}) async {
    final current = now ?? DateTime.now();
    if (_config.simulationMode) {
      final epochWindow = current.millisecondsSinceEpoch ~/ 10000;
      return QrToken(
        token: 'SIM-QR:${_config.terminalId}:$epochWindow',
        expiresAt: current.add(const Duration(seconds: 12)),
      );
    }

    final uri = _buildUri('/terminals/${_config.terminalId}/qr');
    final response = await _sendWithRetry(
      () => _httpClient.get(uri, headers: _headers),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return QrToken.fromJson(decoded, now: current);
    }

    throw TerminalApiException(
      'Falha ao obter QR Code (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Consulta o status do terminal para fallback de presença (US-06).
  /// Tenta GET /terminals/{id}/status e faz fallback para GET /terminals/{id}.
  Future<TerminalStatus> fetchTerminalStatus({DateTime? now}) async {
    final current = now ?? DateTime.now();
    if (_config.simulationMode) {
      return const TerminalStatus(online: true, presenceActive: false);
    }

    final statusUri = _buildUri('/terminals/${_config.terminalId}/status');
    final response = await _sendWithRetry(
      () => _httpClient.get(statusUri, headers: _headers),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return TerminalStatus.fromJson(decoded, now: current);
    }

    // Compatibilidade com a rota já existente GET /api/terminals/:id no backend
    if (response.statusCode == 404) {
      final detailUri = _buildUri('/terminals/${_config.terminalId}');
      final fallbackResp = await _sendWithRetry(
        () => _httpClient.get(detailUri, headers: _headers),
      );
      if (fallbackResp.statusCode >= 200 && fallbackResp.statusCode < 300) {
        final decoded = jsonDecode(fallbackResp.body) as Map<String, dynamic>;
        return TerminalStatus.fromJson(decoded, now: current);
      }
    }

    throw TerminalApiException(
      'Falha ao consultar status do terminal (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Envia o UID da tag NFC para validação em POST /access/nfc (US-10, US-12).
  /// Em caso de falha de rede após retries, retorna AccessDecision.unavailable (nunca libera).
  Future<AccessResult> validateNfcAccess(String uid) async {
    if (_config.simulationMode) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (uid == '00000000' || uid.endsWith('DEAD')) {
        return const AccessResult(
          decision: AccessDecision.denied,
          message: 'Tag NFC não autorizada para este local.',
          reasonCode: 'UNAUTHORIZED',
        );
      }
      return AccessResult(
        decision: AccessDecision.granted,
        message: 'Acesso liberado',
        userName: 'Usuário Simulado ($uid)',
      );
    }

    final uri = _buildUri('/access/nfc');
    final payload = jsonEncode({
      'terminalId': _config.terminalId,
      'uid': uid,
    });

    try {
      final response = await _sendWithRetry(
        () => _httpClient.post(uri, headers: _headers, body: payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return AccessResult.fromJson(decoded);
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        Map<String, dynamic>? body;
        try {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        return AccessResult(
          decision: AccessDecision.denied,
          message: body?['message']?.toString() ?? 'Acesso não autorizado.',
          reasonCode: body?['code']?.toString() ?? 'FORBIDDEN',
        );
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        Map<String, dynamic>? body;
        try {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        return AccessResult(
          decision: AccessDecision.denied,
          message: body?['message']?.toString() ??
              'Credencial não reconhecida ou sem permissão.',
          reasonCode: body?['code']?.toString() ?? 'DENIED',
        );
      }

      // 5xx após retries -> indisponível (fail-closed)
      return AccessResult.unavailable();
    } catch (_) {
      // Sem conexão com o backend -> nunca libera (US-12)
      return AccessResult.unavailable();
    }
  }

  /// Envia o resultado de identificação facial para POST /access/face (US-18).
  Future<AccessResult> validateFaceAccess({
    required String userId,
    required double confidence,
  }) async {
    if (_config.simulationMode) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return AccessResult(
        decision: AccessDecision.granted,
        message: 'Acesso liberado',
        userName: 'Usuário Facial ($userId)',
      );
    }

    final uri = _buildUri('/access/face');
    final payload = jsonEncode({
      'terminalId': _config.terminalId,
      'userId': userId,
      'confidence': confidence,
    });

    try {
      final response = await _sendWithRetry(
        () => _httpClient.post(uri, headers: _headers, body: payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return AccessResult.fromJson(decoded);
      }
      if (response.statusCode >= 400 && response.statusCode < 500) {
        return const AccessResult(
          decision: AccessDecision.denied,
          message: 'Acesso não autorizado.',
        );
      }
      return AccessResult.unavailable();
    } catch (_) {
      return AccessResult.unavailable();
    }
  }
}
