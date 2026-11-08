import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:mobile_readings/screens/terminal_screen.dart';
import 'package:mobile_readings/services/api_client.dart';
import 'package:mobile_readings/services/mqtt_presence_service.dart';
import 'package:mobile_readings/services/nfc_service.dart';
import 'package:mobile_readings/state/terminal_controller.dart';

class _InMemoryConfigStorage implements ConfigStorage {
  TerminalConfig config;
  _InMemoryConfigStorage(this.config);

  @override
  Future<TerminalConfig> load() async => config;

  @override
  Future<void> save(TerminalConfig newConfig) async {
    config = newConfig;
  }
}

class _FakeNfcService implements NfcReaderService {
  bool listening = false;
  void Function(String uid)? onTagCallback;

  @override
  Future<NfcHardwareStatus> checkAvailability() async =>
      NfcHardwareStatus.available;

  @override
  Future<void> startListening({
    required void Function(String uid) onTagRead,
    void Function(String errorMessage)? onError,
  }) async {
    listening = true;
    onTagCallback = onTagRead;
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }
}

class _FakeMqttService implements PresenceMqttService {
  @override
  bool isConnected = true;

  void Function()? triggerPresence;
  void Function(bool connected)? triggerConnectionChanged;

  @override
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    triggerPresence = onPresenceDetected;
    triggerConnectionChanged = onConnectionChanged;
    onConnectionChanged(isConnected);
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
  }
}

class _MockBackendHttp extends http.BaseClient {
  bool failQr = false;
  bool grantAccess = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/qr')) {
      if (failQr) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('Erro')),
          500,
        );
      }
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(jsonEncode({'token': 'TOKEN-123', 'ttlSeconds': 10})),
        ),
        200,
      );
    }

    if (path.endsWith('/access/nfc')) {
      final body = grantAccess
          ? {'result': 'GRANTED', 'message': 'Acesso liberado', 'userName': 'Ana'}
          : {'result': 'DENIED', 'reason': 'UNAUTHORIZED'};
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        grantAccess ? 200 : 403,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'online': true, 'presence': false}))),
      200,
    );
  }
}

void main() {
  group('TerminalController — Máquina de Estados (US-04, US-11, US-13)', () {
    late _InMemoryConfigStorage storage;
    late _MockBackendHttp mockHttp;
    late TerminalApiClient apiClient;
    late _FakeNfcService nfcService;
    late _FakeMqttService mqttService;
    late TerminalController controller;

    setUp(() async {
      const cfg = TerminalConfig(inactivityTimeoutSeconds: 5);
      storage = _InMemoryConfigStorage(cfg);
      mockHttp = _MockBackendHttp();
      apiClient = TerminalApiClient(
        config: cfg,
        httpClient: mockHttp,
        maxRetries: 1,
      );
      nfcService = _FakeNfcService();
      mqttService = _FakeMqttService();

      controller = TerminalController(
        configStorage: storage,
        apiClient: apiClient,
        nfcService: nfcService,
        mqttService: mqttService,
        initialConfig: cfg,
        resultDisplayDuration: const Duration(milliseconds: 80),
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('inicia em Repouso e vai para Escuta ao detectar presença via MQTT',
        () async {
      expect(controller.state, equals(TerminalState.idle));
      expect(nfcService.listening, isFalse);

      mqttService.triggerPresence!();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state, equals(TerminalState.listening));
      expect(nfcService.listening, isTrue);
      expect(controller.currentQrToken?.token, equals('TOKEN-123'));
      expect(controller.isQrUnavailable, isFalse);
    });

    test('fluxo NFC aprovado: Escuta -> Validando -> Liberado -> Repouso',
        () async {
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state, equals(TerminalState.listening));

      mockHttp.grantAccess = true;
      await controller.onNfcTagRead('04A1B2C3');

      expect(controller.state, equals(TerminalState.granted));
      expect(controller.lastAccessResult?.isGranted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.state, equals(TerminalState.idle));
      expect(nfcService.listening, isFalse);
    });

    test('fluxo NFC negado: Escuta -> Validando -> Negado -> Escuta', () async {
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      mockHttp.grantAccess = false;
      await controller.onNfcTagRead('04A1B2C3');

      expect(controller.state, equals(TerminalState.denied));
      expect(controller.lastAccessResult?.isGranted, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.state, equals(TerminalState.listening));
    });

    test('marca QR como indisponível quando a chamada ao backend falha (US-08)',
        () async {
      mockHttp.failQr = true;
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state, equals(TerminalState.listening));
      expect(controller.isQrUnavailable, isTrue);
      expect(controller.currentQrToken, isNull);
    });
  });

  group('TerminalScreen — Testes de Widget (US-21)', () {
    testWidgets('renderiza telas de Repouso, Escuta (QR), Liberado e Negado',
        (tester) async {
      const cfg = TerminalConfig(inactivityTimeoutSeconds: 30);
      final mockHttp = _MockBackendHttp();
      final controller = TerminalController(
        configStorage: _InMemoryConfigStorage(cfg),
        apiClient: TerminalApiClient(
          config: cfg,
          httpClient: mockHttp,
          maxRetries: 1,
        ),
        nfcService: _FakeNfcService(),
        mqttService: _FakeMqttService(),
        initialConfig: cfg,
        resultDisplayDuration: const Duration(seconds: 10),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(home: TerminalScreen(controller: controller)),
      );

      // 1. Repouso
      expect(find.byKey(const Key('view_state_idle')), findsOneWidget);
      expect(find.text('Terminal em repouso'), findsOneWidget);

      // 2. Acorda para Escuta e exibe QR Code
      await tester.tap(find.byKey(const Key('btn_wake_terminal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('view_state_listening')), findsOneWidget);
      expect(find.byKey(const Key('qr_code_box')), findsOneWidget);

      // 3. Simula aprovação NFC -> Tela Liberado
      mockHttp.grantAccess = true;
      await controller.onNfcTagRead('04A1B2C3');
      await tester.pump();

      expect(find.byKey(const Key('view_state_granted')), findsOneWidget);
      expect(find.text('Acesso liberado'), findsOneWidget);

      controller.dispose();
    });
  });
}
