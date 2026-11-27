import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/terminal_config.dart';
import '../models/access_result.dart';
import '../models/qr_token.dart';
import '../models/face_capture.dart';

/// Exceção da camada de API do terminal.
class TerminalApiException implements Exception {
  final String message;
  final int? statusCode;

  final Duration? retryAfter;

  const TerminalApiException(this.message, {this.statusCode, this.retryAfter});

  @override
  String toString() => 'TerminalApiException($statusCode): $message';
}

class TerminalApiClient {
  TerminalConfig _config;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final Duration faceCaptureTimeout;

  TerminalApiClient({
    required TerminalConfig config,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 4),
    this.faceCaptureTimeout = const Duration(seconds: 12),
  })  : _config = config,
        _httpClient = httpClient ?? http.Client();

  TerminalConfig get config => _config;

  void updateConfig(TerminalConfig newConfig) {
    _config = newConfig;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final key = _config.apiKey.trim();
    if (key.isNotEmpty) {
      headers['x-terminal-key'] = key;
    }
    return headers;
  }

  Future<void> checkConnection(String address) async {
    final baseUrl = TerminalConfig.normalizeServerAddress(address);
    if (baseUrl == null) {
      throw const TerminalApiException(
        'Informe uma URL HTTP/HTTPS ou IP:porta válido.',
      );
    }
    final request = http.Request('GET', Uri.parse('$baseUrl/health'))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final http.Response response;
    try {
      response = await _httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const TerminalApiException('O servidor demorou para responder.');
    } on Exception {
      throw const TerminalApiException(
        'Não foi possível alcançar o servidor. Confira o endereço e a rede.',
      );
    }
    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['status'] == 'ok') return;
      } on FormatException {
        // Uma resposta incompatível não confirma a saúde da API.
      }
    }
    throw const TerminalApiException(
      'O endereço respondeu, mas o serviço de saúde da API não retornou OK.',
    );
  }

  Future<String> identifyTerminal(TerminalConfig candidate) async {
    final request = http.Request(
      'GET',
      Uri.parse('${candidate.backendBaseUrl}/terminals/me'),
    )
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'x-terminal-key': candidate.apiKey,
      });
    late final http.Response response;
    try {
      response = await _httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(requestTimeout);
    } on Exception {
      throw const TerminalApiException('Servidor indisponível.');
    }

    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw const TerminalApiException('Chave do terminal rejeitada.');
    }
    if (status >= 500) {
      throw const TerminalApiException('Servidor indisponível.');
    }
    if (status == 429) {
      throw const TerminalApiException(
        'Muitas tentativas. Aguarde antes de tentar novamente.',
      );
    }
    if (status == 200) {
      try {
        final decoded = jsonDecode(response.body);
        final id = decoded is Map ? decoded['id'] : null;
        if (id is String && TerminalConfig.terminalIdPattern.hasMatch(id)) {
          return id;
        }
      } on FormatException {
        // A resposta deve conter o identificador no formato oficial.
      }
    }
    throw const TerminalApiException('Resposta incompatível do servidor.');
  }

  Future<bool> fetchPresence() async {
    final request = http.Request(
      'GET',
      _buildUri('/terminals/${_config.terminalId}/status'),
    )
      ..followRedirects = false
      ..headers.addAll(_headers);
    final response = await _httpClient
        .send(request)
        .then(http.Response.fromStream)
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw TerminalApiException('Presença indisponível.', statusCode: response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['presenceActive'] is bool) {
      return decoded['presenceActive'] as bool;
    }
    throw const TerminalApiException('Resposta de presença inválida.');
  }

  Uri _buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${_config.backendBaseUrl}$cleanPath');
  }

  Future<QrToken> fetchQrToken() async {
    final request = http.Request('POST', _buildUri('/terminals/me/qr'))
      ..followRedirects = false
      ..headers.addAll(_headers);
    final response = await _httpClient
        .send(request)
        .then(http.Response.fromStream)
        .timeout(requestTimeout);
    final status = response.statusCode;
    if (status == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return QrToken.fromJson(decoded);
      throw const FormatException('Formato do QR Code incompatível.');
    }

    final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
    throw TerminalApiException(
      'Falha ao obter QR Code (HTTP $status).',
      statusCode: status,
      retryAfter: retrySeconds != null && retrySeconds > 0
          ? Duration(seconds: retrySeconds)
          : null,
    );
  }

  Future<AccessResult> recognizeFace(List<List<int>> photos) async {
    if (!_config.isConfigured) {
      return AccessResult.unavailable('Configure o terminal para acessar.');
    }
    if (photos.isEmpty ||
        photos.length > maxFaceCaptures ||
        !photos.every(isSupportedFaceJpeg)) {
      return AccessResult.unavailable(
        'A câmera precisa produzir imagens JPEG de até 100 KB.',
      );
    }

    try {
      final abort = Completer<void>();
      final request = http.AbortableMultipartRequest(
        'POST',
        _buildUri('/access/face/capture'),
        abortTrigger: abort.future,
      )
        ..followRedirects = false
        ..headers.addAll(_headers)
        ..headers['x-face-attempt-id'] = _newAttemptId();

      for (final photo in photos) {
        request.files.add(http.MultipartFile.fromBytes(
          'photos',
          photo,
          filename: 'photo.jpg',
          contentType: http.MediaType('image', 'jpeg'),
        ));
      }

      final response = await _httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(faceCaptureTimeout, onTimeout: () {
        abort.complete();
        throw TimeoutException('Facial access request timed out');
      });
      return _readFaceDecision(response);
    } on TimeoutException {
      return AccessResult.unavailable(
          'A validação facial demorou para responder.');
    } on FormatException {
      return AccessResult.unavailable('Resposta incompatível do servidor.');
    } on Exception {
      return AccessResult.unavailable();
    }
  }

  AccessResult _readFaceDecision(http.Response response) {
    final status = response.statusCode;
    if (status >= 500) {
      return AccessResult.unavailable('Serviço facial indisponível.');
    }
    if (status == 401) {
      return AccessResult.unavailable('Chave do terminal rejeitada.');
    }
    if (status == 429) {
      return AccessResult.unavailable(
          'Muitas tentativas. Aguarde e tente novamente.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid facial access response');
    }

    final result = decoded['result'];
    final allowed = decoded['allowed'];
    final message = decoded['message'];
    if (status == 200 && result == 'GRANTED' && allowed == true) {
      final name = decoded['userName'];
      return AccessResult(
        decision: AccessDecision.granted,
        message: message is String ? message : 'Acesso liberado',
        userName: name is String ? name : null,
      );
    }
    if (status == 403 && result == 'DENIED' && allowed == false) {
      final reason = decoded['reason'];
      return AccessResult(
        decision: AccessDecision.denied,
        message: message is String ? message : 'Acesso não autorizado.',
        reasonCode: reason is String ? reason : null,
      );
    }

    final error = decoded['error'];
    final code = error is Map ? error['code'] : null;
    return switch (code) {
      'NO_FACE' => const AccessResult(
          decision: AccessDecision.denied,
          message:
              'Nenhum rosto detectado. Ajuste a posição e tente novamente.',
          reasonCode: 'NO_FACE',
        ),
      'MULTIPLE_FACES' => const AccessResult(
          decision: AccessDecision.denied,
          message: 'Mantenha apenas um rosto no enquadramento.',
          reasonCode: 'MULTIPLE_FACES',
        ),
      'FACE_NO_COMPATIBLE_TEMPLATES' =>
        AccessResult.unavailable('Sem cadastro facial compatível neste local.'),
      'PHOTO_TOO_LARGE' ||
      'FILE_TOO_LARGE' ||
      'IMAGE_DIMENSIONS_TOO_LARGE' =>
        AccessResult.unavailable('A imagem excede os limites do servidor.'),
      'CORRUPT_IMAGE' || 'UNSUPPORTED_IMAGE_TYPE' => AccessResult.unavailable(
          'A imagem da câmera está inválida. Tente novamente.'),
      'FACE_ATTEMPT_REPLAYED' => AccessResult.unavailable(
          'Esta tentativa já foi processada. Inicie uma nova captura.',
        ),
      _ => AccessResult.unavailable('Resposta incompatível do servidor.'),
    };
  }

  String _newAttemptId() {
    final random = Random.secure();
    final bytes =
        List.generate(16, (_) => random.nextInt(256), growable: false);
    // UUID v4 e variante RFC 9562.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
