import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:mobile_readings/screens/terminal_screen.dart';
import 'package:mobile_readings/services/api_client.dart';
import 'package:mobile_readings/services/mqtt_presence_service.dart';
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

class _FakeMqttService implements PresenceMqttService {
  @override
  bool isConnected = true;

  void Function()? triggerPresence;
  void Function(bool connected)? triggerConnectionChanged;
  void Function(bool busy)? triggerReaderBusy;

  @override
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
    void Function(bool isBusy)? onReaderBusyChanged,
  }) async {
    triggerPresence = onPresenceDetected;
    triggerConnectionChanged = onConnectionChanged;
    triggerReaderBusy = onReaderBusyChanged;
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

    if (path.endsWith('/access/facial') ||
        path.endsWith('/access/face') ||
        path.endsWith('/access/nfc')) {
      final body = grantAccess
          ? {'result': 'GRANTED', 'message': 'Acesso liberado', 'userName': 'Ana'}
          : {'result': 'DENIED', 'message': 'Não autorizado'};
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        grantAccess ? 200 : 403,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
    );
  }
}

void main() {
  group('TerminalController — Testes de Estado e Integração', () {
    late _InMemoryConfigStorage storage;
    late _MockBackendHttp mockHttp;
    late TerminalApiClient apiClient;
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
      mqttService = _FakeMqttService();

      controller = TerminalController(
        configStorage: storage,
        apiClient: apiClient,
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

      mqttService.triggerPresence!();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state, equals(TerminalState.listening));
      expect(controller.currentQrToken?.token, equals('TOKEN-123'));
      expect(controller.isQrUnavailable, isFalse);
    });

    test('fluxo facial aprovado: Escuta -> Validando -> Liberado -> Repouso',
        () async {
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state, equals(TerminalState.listening));

      mockHttp.grantAccess = true;
      await controller.onFaceIdentified(userId: 'u123', confidence: 0.95);

      expect(controller.state, equals(TerminalState.granted));
      expect(controller.lastAccessResult?.isGranted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.state, equals(TerminalState.idle));
    });

    test('fluxo facial negado: Escuta -> Validando -> Negado -> Escuta', () async {
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      mockHttp.grantAccess = false;
      await controller.onFaceIdentified(userId: 'u123', confidence: 0.95);

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

    test('sinaliza leitor ocupado quando recebe evento MQTT de gravação (US-10)',
        () async {
      expect(controller.isReaderBusy, isFalse);

      mqttService.triggerReaderBusy?.call(true);
      expect(controller.isReaderBusy, isTrue);

      mqttService.triggerReaderBusy?.call(false);
      expect(controller.isReaderBusy, isFalse);
    });

    test('rejeita biometria com luz fraca com aviso acessível (US-19, US-20)',
        () async {
      controller.onPresenceDetected();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.evaluateCapturedFace([0.1, 0.2, 0.3], lightLevel: 0.2);
      expect(controller.statusMessage, contains('Iluminação insuficiente'));
    });

    test('executa ensaio E2E completo até liberação de trava (US-22)', () async {
      expect(controller.state, equals(TerminalState.idle));
      mockHttp.grantAccess = true;

      final demoFuture = controller.runE2eDemo();
      expect(controller.isE2eDemoRunning, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(controller.state, equals(TerminalState.listening));
      expect(controller.isFaceModeEnabled, isTrue);

      await demoFuture;
      expect(controller.isE2eDemoRunning, isFalse);
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

      // 3. Simula aprovação facial -> Tela Liberado
      mockHttp.grantAccess = true;
      await controller.onFaceIdentified(userId: 'u123', confidence: 0.95);
      await tester.pump();

      expect(find.byKey(const Key('view_state_granted')), findsOneWidget);
      expect(find.text('Acesso liberado'), findsOneWidget);
      expect(find.byKey(const Key('relay_lock_feedback_box')), findsOneWidget);
      expect(find.text('Trava Solenoide / Relé'), findsOneWidget);

      controller.dispose();
    });
  });
}
