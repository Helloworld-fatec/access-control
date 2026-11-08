import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class QrConsumeException implements Exception {
  const QrConsumeException({
    this.statusCode,
    this.code,
    this.reason,
    this.accessLogId,
    required this.message,
  });
  final int? statusCode;
  final String? code;
  final String? reason;
  final String? accessLogId;
  final String message;
}

class ApiClient {
  ApiClient(this.baseUrl, this.token, this.client);
  final String baseUrl;
  final String? token;
  final http.Client client;

  static String normalize(String value) {
    var s = value.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.toLowerCase().endsWith('/api')) s = s.substring(0, s.length - 4);
    final u = Uri.tryParse(s);
    if (u == null ||
        !['http', 'https'].contains(u.scheme) ||
        u.host.isEmpty ||
        u.hasQuery ||
        u.hasFragment ||
        u.userInfo.isNotEmpty) {
      throw const ApiException(
        'Informe uma URL válida, ex.: http://192.168.0.10:3000',
      );
    }
    return s;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await client
        .post(
          Uri.parse('$baseUrl/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    return decode(r);
  }

  Future<Map<String, dynamic>> authorizations() async {
    final r = await client
        .get(
          Uri.parse('$baseUrl/api/authorizations/me?page=1&pageSize=100'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    return decode(r);
  }

  Future<Map<String, dynamic>> consumeQr(String qrToken) async {
    final r = await client
        .post(
          Uri.parse('$baseUrl/api/access/qr/consume'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'token': qrToken}),
        )
        .timeout(const Duration(seconds: 20));
    dynamic d;
    try {
      d = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw const QrConsumeException(message: 'Resposta inválida do servidor.');
    }
    if (d is! Map<String, dynamic>)
      throw const QrConsumeException(message: 'Resposta inválida do servidor.');
    if (r.statusCode >= 200 && r.statusCode < 300) return d;
    final error = d['error'];
    throw QrConsumeException(
      statusCode: r.statusCode,
      code: error is Map ? error['code'] as String? : null,
      reason: d['reason'] as String?,
      accessLogId: d['accessLogId'] as String?,
      message: error is Map && error['message'] is String
          ? error['message'] as String
          : 'Falha HTTP ${r.statusCode}',
    );
  }

  Map<String, dynamic> decode(http.Response r) {
    dynamic d;
    try {
      d = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw ApiException(
        'Resposta inválida do servidor.',
        statusCode: r.statusCode,
      );
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final m = d is Map && d['error'] is Map ? d['error']['message'] : null;
      throw ApiException(
        m is String ? m : 'Falha HTTP ${r.statusCode}',
        statusCode: r.statusCode,
      );
    }
    if (d is! Map<String, dynamic>)
      throw const ApiException('Resposta inválida do servidor.');
    return d;
  }
}
