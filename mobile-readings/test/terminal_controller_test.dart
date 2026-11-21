import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:mobile_readings/screens/terminal_screen.dart';
import 'package:mobile_readings/services/api_client.dart';
import 'package:mobile_readings/state/terminal_controller.dart';

const _configuredTerminal = TerminalConfig(
  serverAddress: 'http://127.0.0.1:3000/api',
  apiKey: 'ab12ef',
  terminalId: '14825695-6cdb-4e40-a33e-94045475eabb',
  voiceAccessibilityEnabled: false,
);

class _InMemoryConfigStorage implements ConfigStorage {
  TerminalConfig config = _configuredTerminal;

  @override
  Future<TerminalConfig> load() async => config;

  @override
  Future<void> save(TerminalConfig config) async => this.config = config;
}

class _Backend extends http.BaseClient {
  static const token = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefg';

  final requests = <http.BaseRequest>[];
  Future<http.StreamedResponse> Function() qr = () async => qrResponse();
  Future<http.StreamedResponse> Function() face =
      () async => response({'result': 'GRANTED', 'allowed': true});

  static http.StreamedResponse qrResponse() => response({
        'payload': {'v': 1, 'token': token},
        'expiresAt':
            DateTime.now().add(const Duration(seconds: 20)).toIso8601String(),
        'refreshAfterSeconds': 10,
      });

  static http.StreamedResponse response(Object body, [int status = 200]) =>
      http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(body))), status);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    if (request.url.path.endsWith('/terminals/me')) {
      return Future.value(response({'id': _configuredTerminal.terminalId}));
    }
    if (request.url.path == '/api/access/face/capture') return face();
    expect(request.method, 'POST');
    expect(request.url.path, '/api/terminals/me/qr');
    return qr();
  }
}

void main() {
  late _Backend backend;
  late TerminalController controller;

  setUp(() async {
    backend = _Backend();
    controller = TerminalController(
      configStorage: _InMemoryConfigStorage(),
      apiClient: TerminalApiClient(
        config: _configuredTerminal,
        httpClient: backend,
      ),
    );
    await controller.initialize();
  });

  tearDown(() => controller.dispose());

  testWidgets(
      'manual activation opens the choice without contacting the server',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(controller: controller)),
    );
    await tester.tap(find.byKey(const Key('btn_wake_terminal')));
    await tester.pumpAndSettle();

    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('Reconhecimento facial'), findsOneWidget);
    expect(backend.requests, isEmpty);

    await tester.tap(find.text('QR Code'));
    await tester.pump();
    await tester.pump();
    expect(
        controller.currentQrToken?.payload, {'v': 1, 'token': _Backend.token});
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final requestCount = backend.requests.length;
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.state, TerminalState.choosing);
    expect(controller.currentQrToken, isNull);
    expect(backend.requests, hasLength(requestCount));
    controller.returnToIdle();
  });

  test('ignores an old QR response even after reentering QR mode', () async {
    final firstResponse = Completer<http.StreamedResponse>();
    final secondResponse = Completer<http.StreamedResponse>();
    backend.qr = () => firstResponse.future;
    controller.activate();
    controller.showQr();
    controller.showFacial();
    backend.qr = () => secondResponse.future;
    controller.showQr();

    expect(backend.requests, hasLength(1));
    firstResponse.complete(_Backend.qrResponse());
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentQrToken, isNull);
    expect(controller.isQrLoading, isTrue);
    expect(backend.requests, hasLength(2));

    secondResponse.complete(_Backend.qrResponse());
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentQrToken?.payload['token'], _Backend.token);
  });

  test('displays unavailable QR and allows a successful retry', () async {
    backend.qr = () async => _Backend.response({}, 503);
    controller.activate();
    controller.showQr();
    await Future<void>.delayed(Duration.zero);
    expect(controller.qrError, isNotNull);

    backend.qr = () async => _Backend.qrResponse();
    await controller.refreshQrCodeNow();
    expect(controller.qrError, isNull);
    expect(controller.currentQrToken?.payload['token'], _Backend.token);
  });

  test('keeps a previous token only until expiry after failed refresh',
      () async {
    backend.qr = () async => _Backend.response({
          'payload': {'v': 1, 'token': _Backend.token},
          'expiresAt': DateTime.now()
              .add(const Duration(milliseconds: 300))
              .toIso8601String(),
          'refreshAfterSeconds': 10,
        });
    controller.activate();
    controller.showQr();
    await Future<void>.delayed(Duration.zero);
    expect(controller.currentQrToken, isNotNull);

    backend.qr = () async => _Backend.response({}, 503);
    await controller.refreshQrCodeNow();
    expect(controller.qrError, isNotNull);
    expect(controller.currentQrToken, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(controller.currentQrToken, isNull);
    expect(controller.canRetryQr, isTrue);
  });

  test('renews according to the cadence received from the server', () async {
    final renewed = Completer<void>();
    backend.qr = () async {
      if (backend.requests.length == 2) renewed.complete();
      return _Backend.response({
        'payload': {'v': 1, 'token': _Backend.token},
        'expiresAt':
            DateTime.now().add(const Duration(seconds: 20)).toIso8601String(),
        'refreshAfterSeconds': 1,
      });
    };
    controller.activate();
    controller.showQr();
    await Future<void>.delayed(Duration.zero);
    expect(backend.requests, hasLength(1));
    await renewed.future.timeout(const Duration(seconds: 3));
    expect(backend.requests, hasLength(2));
  });

  test('suppresses reissuance after a key rejection across mode changes',
      () async {
    backend.qr = () async => _Backend.response({}, 401);
    controller.activate();
    controller.showQr();
    await Future<void>.delayed(Duration.zero);
    expect(controller.canRetryQr, isFalse);
    expect(controller.qrError, contains('Chave do terminal rejeitada'));

    controller.showChoices();
    controller.showQr();
    await controller.refreshQrCodeNow();
    expect(backend.requests, hasLength(1));
  });

  test('honors Retry-After across mode changes and manual requests', () async {
    backend.qr = () async => http.StreamedResponse(
          Stream.value(utf8.encode('{}')),
          429,
          headers: {'retry-after': '30'},
        );
    controller.activate();
    controller.showQr();
    await Future<void>.delayed(Duration.zero);
    expect(controller.canRetryQr, isFalse);

    controller.showChoices();
    controller.showQr();
    await controller.refreshQrCodeNow();
    expect(controller.qrError, contains('Limite de emiss'));
    expect(backend.requests, hasLength(1));
  });

  test('discards a late facial capture after changing mode', () async {
    final capture = Completer<List<List<int>>>();
    controller.activate();
    controller.showFacial();
    final recognition = controller.startRecognition(() => capture.future);
    expect(controller.isCapturing, isTrue);

    controller.showQr();
    capture.complete([
      [1, 2, 3]
    ]);
    await recognition;
    expect(controller.state, TerminalState.qr);
    expect(controller.facialResult, isNull);
    expect(controller.isCapturing, isFalse);
    expect(backend.requests, hasLength(1));
  });

  test(
      'only displays the backend decision after capture and clears it on return',
      () async {
    final pending = Completer<http.StreamedResponse>();
    backend.face = () => pending.future;
    controller.activate();
    controller.showFacial();
    final recognition = controller.startRecognition(
      () async => [
        [0xff, 0xd8, 0xff, 0xd9]
      ],
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, TerminalState.validatingFacial);
    expect(controller.facialResult, isNull);
    pending.complete(_Backend.response({'result': 'GRANTED', 'allowed': true}));
    await recognition;

    expect(controller.state, TerminalState.facialResult);
    expect(controller.facialResult!.isGranted, isTrue);
    controller.returnToIdle();
    expect(controller.facialResult, isNull);
    expect(backend.requests, hasLength(1));
  });

  test('ignores a late backend grant after leaving facial mode', () async {
    final pending = Completer<http.StreamedResponse>();
    backend.face = () => pending.future;
    controller.activate();
    controller.showFacial();
    final recognition = controller.startRecognition(
      () async => [
        [0xff, 0xd8, 0xff, 0xd9]
      ],
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, TerminalState.validatingFacial);

    controller.showQr();
    pending.complete(_Backend.response({'result': 'GRANTED', 'allowed': true}));
    await recognition;

    expect(controller.state, TerminalState.qr);
    expect(controller.facialResult, isNull);
  });

  test('shows a backend denial and allows switching to QR', () async {
    backend.face = () async => _Backend.response({
          'result': 'DENIED',
          'allowed': false,
          'reason': 'NO_AUTHORIZATION',
        }, 403);
    controller.activate();
    controller.showFacial();

    await controller.startRecognition(() async => [
          [0xff, 0xd8, 0xff, 0xd9]
        ]);

    expect(controller.facialResult!.reasonCode, 'NO_AUTHORIZATION');
    expect(controller.facialResult!.isGranted, isFalse);
    controller.showQr();
    expect(controller.state, TerminalState.qr);
    expect(controller.facialResult, isNull);
  });

  test('camera failure supports retry and QR fallback', () async {
    controller.activate();
    controller.showFacial();
    await controller.startRecognition(() async => throw Exception());
    expect(controller.state, TerminalState.facialResult);
    expect(controller.facialResult!.isUnavailable, isTrue);

    controller.showFacial();
    expect(controller.facialResult, isNull);
    controller.cameraUnavailable();
    controller.showQr();
    expect(controller.state, TerminalState.qr);
    expect(controller.facialResult, isNull);
  });

  test('clears the current mode when server configuration changes', () async {
    final pendingQr = Completer<http.StreamedResponse>();
    backend.qr = () => pendingQr.future;
    controller.activate();
    controller.showQr();
    await controller.configureTerminal('https://server.example', 'ABC123');

    pendingQr.complete(_Backend.qrResponse());
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, TerminalState.idle);
    expect(controller.currentQrToken, isNull);
    expect(controller.config.apiKey, 'abc123');
    expect(controller.config.backendBaseUrl, 'https://server.example/api');
  });
}
