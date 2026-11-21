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
    serverAddress: 'http://192.168.1.10:3000/api',
    terminalId: '14825695-6cdb-4e40-a33e-94045475eabb',
    apiKey: 'ab12ef',
  );

  test('identifies the terminal with the candidate configuration', () async {
    const id = '14825695-6cdb-4e40-a33e-94045475eabb';
    final candidate = testConfig.copyWith(
      serverAddress: 'https://server.example:8443/api',
      apiKey: 'ab12ef',
    );
    final fakeHttp = _FakeHttpClient((request, _) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://server.example:8443/api/terminals/me',
      );
      expect(request.headers['x-terminal-key'], 'ab12ef');
      expect(request.followRedirects, isFalse);
      return http.Response(jsonEncode({'id': id}), 200);
    });
    final client = TerminalApiClient(config: testConfig, httpClient: fakeHttp);

    expect(await client.identifyTerminal(candidate), id);
    expect(client.config, same(testConfig));
  });

  group('TerminalApiClient (US-03, US-12)', () {
    test('issues QR once and keeps the official payload and timing', () async {
      const token = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg';
      const payload = {'v': 1, 'token': token, 'extra': 'kept'};
      final fakeHttp = _FakeHttpClient((request, _) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/terminals/me/qr');
        expect(request.headers['x-terminal-key'], 'ab12ef');
        expect(request.followRedirects, isFalse);
        return http.Response(
            jsonEncode({
              'payload': payload,
              'expiresAt': '2026-11-21T13:00:20Z',
              'refreshAfterSeconds': 10,
            }),
            200);
      });
      final client =
          TerminalApiClient(config: testConfig, httpClient: fakeHttp);

      final qr = await client.fetchQrToken();
      expect(qr.payload, payload);
      expect(qr.expiresAt, DateTime.utc(2026, 11, 21, 13, 0, 20));
      expect(qr.refreshAfterSeconds, 10);
      expect(fakeHttp.callCount, 1);
    });

    test('exposes Retry-After and never retries an issuance POST', () async {
      final fakeHttp = _FakeHttpClient((_, __) async =>
          http.Response('{}', 429, headers: {'retry-after': '37'}));
      final client =
          TerminalApiClient(config: testConfig, httpClient: fakeHttp);

      await expectLater(
        client.fetchQrToken(),
        throwsA(isA<TerminalApiException>()
            .having((error) => error.statusCode, 'status', 429)
            .having((error) => error.retryAfter, 'retryAfter',
                const Duration(seconds: 37))),
      );
      expect(fakeHttp.callCount, 1);
    });
  });

  group('Facial capture', () {
    const jpeg = [0xff, 0xd8, 0xff, 0xd9];

    test('sends one JPEG batch per attempt with a fresh UUID', () async {
      final ids = <String>{};
      final client = TerminalApiClient(
        config: testConfig,
        httpClient: _FakeHttpClient((request, _) async {
          expect(request, isA<http.MultipartRequest>());
          final multipart = request as http.MultipartRequest;
          expect(multipart.method, 'POST');
          expect(multipart.url.path, '/api/access/face/capture');
          expect(multipart.followRedirects, isFalse);
          expect(multipart.headers['x-terminal-key'], 'ab12ef');
          final attempt = multipart.headers['x-face-attempt-id']!;
          expect(
              attempt,
              matches(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ));
          expect(ids.add(attempt), isTrue);
          expect(multipart.fields, isEmpty);
          expect(multipart.files, hasLength(3));
          for (final file in multipart.files) {
            expect(file.field, 'photos');
            expect(file.contentType.toString(), 'image/jpeg');
            expect(await file.finalize().toBytes(), jpeg);
          }
          return http.Response('{"result":"GRANTED","allowed":true}', 200);
        }),
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await client.recognizeFace([jpeg, jpeg, jpeg]);
        expect(result.isGranted, isTrue);
      }
      expect(ids, hasLength(2));
    });

    test('rejects incomplete or contradictory grant responses', () async {
      for (final body in [
        '{}',
        '{"allowed":true}',
        '{"result":"GRANTED"}',
        '{"result":"GRANTED","allowed":false}',
        '{"result":"DENIED","allowed":true}',
        '{"granted":true}',
      ]) {
        final client = TerminalApiClient(
          config: testConfig,
          httpClient:
              _FakeHttpClient((_, __) async => http.Response(body, 200)),
        );

        expect((await client.recognizeFace([jpeg])).isUnavailable, isTrue);
      }
    });

    test('maps the official refusal, invalid capture and unavailable service',
        () async {
      final cases = [
        (403, '{"result":"DENIED","allowed":false}', AccessDecision.denied),
        (422, '{"error":{"code":"NO_FACE"}}', AccessDecision.denied),
        (422, '{"error":{"code":"CORRUPT_IMAGE"}}', AccessDecision.unavailable),
        (401, '{}', AccessDecision.unavailable),
        (502, '{}', AccessDecision.unavailable),
        (
          503,
          '{"result":"GRANTED","allowed":true}',
          AccessDecision.unavailable
        ),
      ];
      for (final (status, body, expected) in cases) {
        final fake =
            _FakeHttpClient((_, __) async => http.Response(body, status));
        final client = TerminalApiClient(config: testConfig, httpClient: fake);

        expect((await client.recognizeFace([jpeg])).decision, expected);
        expect(fake.callCount, 1);
      }
    });

    test('fails closed on network failure without retry', () async {
      final fake =
          _FakeHttpClient((_, __) async => throw TimeoutException('Network'));
      final client = TerminalApiClient(config: testConfig, httpClient: fake);

      expect((await client.recognizeFace([jpeg])).isUnavailable, isTrue);
      expect(fake.callCount, 1);
    });

    test('does not upload an oversized or invalid camera image', () async {
      final fake =
          _FakeHttpClient((_, __) async => throw StateError('Unexpected POST'));
      final client = TerminalApiClient(config: testConfig, httpClient: fake);
      final tooLarge = List.filled(102401, 0)..setAll(0, jpeg);

      expect((await client.recognizeFace([tooLarge])).isUnavailable, isTrue);
      expect(
          (await client.recognizeFace([
            [0, 1, 2]
          ]))
              .isUnavailable,
          isTrue);
      expect(fake.callCount, 0);
    });
  });
}
