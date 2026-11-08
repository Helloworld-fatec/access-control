import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:mobile_readings/models/access_result.dart';
import 'package:mobile_readings/services/api_client.dart';

class _FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request, int attempt)
      handler;
  int callCount = 0;

  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    final response = await handler(request, callCount);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  const testConfig = TerminalConfig(
    backendHost: '192.168.1.10',
    backendPort: 3000,
    terminalId: 'term-01',
    apiKey: 'secret-terminal-key',
  );

  group('TerminalApiClient (US-03, US-12)', () {
    test('envia x-api-key e faz retry automático em falha temporária', () async {
      final fakeHttp = _FakeHttpClient((req, attempt) async {
        expect(req.headers['x-api-key'], equals('secret-terminal-key'));
        if (attempt < 3) {
          return http.Response('Erro interno', 503);
        }
        return http.Response(
          jsonEncode({
            'token': 'QR-TOKEN-XYZ',
            'ttlSeconds': 10,
          }),
          200,
        );
      });

      final client = TerminalApiClient(
        config: testConfig,
        httpClient: fakeHttp,
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 5),
      );

      final qr = await client.fetchQrToken();
      expect(qr.token, equals('QR-TOKEN-XYZ'));
      expect(fakeHttp.callCount, equals(3));
    });

    test('nega acesso de forma segura (fail-closed) quando sem rede (US-12)',
        () async {
      final fakeHttp = _FakeHttpClient((req, attempt) async {
        throw TimeoutException('Timeout de conexão');
      });

      final client = TerminalApiClient(
        config: testConfig,
        httpClient: fakeHttp,
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 5),
      );

      final result = await client.validateNfcAccess('04A1B2C3');
      expect(result.isGranted, isFalse);
      expect(result.decision, equals(AccessDecision.unavailable));
      expect(fakeHttp.callCount, equals(3));
    });
  });
}
