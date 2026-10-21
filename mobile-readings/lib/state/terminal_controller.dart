import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/terminal_config.dart';
import '../models/access_result.dart';
import '../models/qr_token.dart';
import '../services/api_client.dart';
import '../services/mqtt_presence_service.dart';
import '../services/nfc_service.dart';

/// Estados oficiais do Terminal de Acesso (US-04).
enum TerminalState {
  /// Repouso: tela econômica, câmera desligada e leitor NFC inativo (US-13).
  idle,

  /// Escuta: QR Code rotativo visível e leitura NFC ativa.
  listening,

  /// Validando: credencial enviada ao backend, aguardando decisão.
  validating,

  /// Liberado: tela verde, ícone de confirmação e retorno a Repouso após poucos segundos.
  granted,

  /// Negado: tela vermelha, motivo genérico/indisponibilidade e retorno a Escuta após poucos segundos.
  denied,
}

/// Controlador central da máquina de estados e orquestração de serviços do Terminal (US-04 a US-13).
class TerminalController extends ChangeNotifier {
  final ConfigStorage _configStorage;
  final TerminalApiClient _apiClient;
  final NfcReaderService _nfcService;
  final PresenceMqttService _mqttService;
  final NfcCooldownGuard _nfcCooldownGuard;

  final Duration qrRefreshInterval;
  final Duration presencePollingInterval;
  final Duration resultDisplayDuration;

  TerminalConfig _config;
  TerminalState _state = TerminalState.idle;
  QrToken? _currentQrToken;
  bool _qrUnavailable = false;
  bool _mqttConnected = false;
  NfcHardwareStatus _nfcHardwareStatus = NfcHardwareStatus.available;
  AccessResult? _lastAccessResult;
  String? _statusMessage;

  Timer? _inactivityTimer;
  Timer? _qrRefreshTimer;
  Timer? _qrExpiryGuardTimer;
  Timer? _resultReturnTimer;
  Timer? _presenceFallbackTimer;
  bool _disposed = false;

  TerminalController({
    required ConfigStorage configStorage,
    required TerminalApiClient apiClient,
    required NfcReaderService nfcService,
    required PresenceMqttService mqttService,
    NfcCooldownGuard? nfcCooldownGuard,
    TerminalConfig initialConfig = const TerminalConfig(),
    this.qrRefreshInterval = const Duration(seconds: 10),
    this.presencePollingInterval = const Duration(seconds: 2),
    this.resultDisplayDuration = const Duration(seconds: 3),
  })  : _configStorage = configStorage,
        _apiClient = apiClient,
        _nfcService = nfcService,
        _mqttService = mqttService,
        _nfcCooldownGuard = nfcCooldownGuard ?? NfcCooldownGuard(),
        _config = initialConfig;

  // ───────────── Getters de Estado ─────────────

  TerminalConfig get config => _config;
  TerminalState get state => _state;
  QrToken? get currentQrToken => _currentQrToken;
  bool get isQrUnavailable => _qrUnavailable || _currentQrToken == null;
  bool get isMqttConnected => _mqttConnected;
  bool get isFallbackPollingActive =>
      _presenceFallbackTimer != null && _presenceFallbackTimer!.isActive;
  NfcHardwareStatus get nfcHardwareStatus => _nfcHardwareStatus;
  AccessResult? get lastAccessResult => _lastAccessResult;
  String? get statusMessage => _statusMessage;

  // ───────────── Inicialização e Configuração ─────────────

  Future<void> initialize() async {
    _config = await _configStorage.load();
    _apiClient.updateConfig(_config);
    _nfcHardwareStatus = await _nfcService.checkAvailability();
    _notifySafely();
    await _connectPresenceChannels();
  }

  /// Atualiza e aplica imediatamente as configurações sem reiniciar o app (US-02).
  Future<void> updateConfig(TerminalConfig newConfig) async {
    _config = newConfig;
    await _configStorage.save(newConfig);
    _apiClient.updateConfig(newConfig);

    if (_state == TerminalState.listening) {
      _resetInactivityTimer();
      await refreshQrCodeNow();
    }

    await _connectPresenceChannels();
    _notifySafely();
  }

  Future<void> _connectPresenceChannels() async {
    await _mqttService.connect(
      config: _config,
      onPresenceDetected: onPresenceDetected,
      onConnectionChanged: _handleMqttConnectionChanged,
    );
  }

  void _handleMqttConnectionChanged(bool connected) {
    _mqttConnected = connected;
    if (connected) {
      // Quando o MQTT volta, o polling de fallback é interrompido (US-06)
      _stopPresenceFallbackPolling();
    } else {
      // Se o MQTT cair, inicia polling em GET /terminals/{id}/status (US-06)
      _startPresenceFallbackPolling();
    }
    _notifySafely();
  }

  void _startPresenceFallbackPolling() {
    _presenceFallbackTimer?.cancel();
    _presenceFallbackTimer = Timer.periodic(presencePollingInterval, (_) async {
      if (_mqttConnected) {
        _stopPresenceFallbackPolling();
        return;
      }
      if (_state != TerminalState.idle) return;
      try {
        final status = await _apiClient.fetchTerminalStatus();
        if (status.presenceActive) {
          onPresenceDetected();
        }
      } catch (_) {
        // Silencia erro de polling de presença em background
      }
    });
  }

  void _stopPresenceFallbackPolling() {
    _presenceFallbackTimer?.cancel();
    _presenceFallbackTimer = null;
  }

  // ───────────── Transições da Máquina de Estados (US-04) ─────────────

  /// Evento de presença: leva de Repouso a Escuta ou renova o tempo de atividade em Escuta.
  void onPresenceDetected() {
    if (_state == TerminalState.idle) {
      _enterListeningState();
    } else if (_state == TerminalState.listening) {
      _resetInactivityTimer();
    }
  }

  /// Força retorno imediato ao estado de Repouso (US-13).
  void returnToIdle() {
    _enterIdleState();
  }

  void _enterIdleState() {
    _cancelOperationalTimers();
    _currentQrToken = null;
    _qrUnavailable = false;
    _lastAccessResult = null;
    _statusMessage = null;
    _state = TerminalState.idle;
    unawaited(_nfcService.stopListening());
    _notifySafely();
  }

  void _enterListeningState() {
    _resultReturnTimer?.cancel();
    _lastAccessResult = null;
    _statusMessage = null;
    _state = TerminalState.listening;
    _resetInactivityTimer();
    _startQrPolling();
    unawaited(_startNfcInListening());
    _notifySafely();
  }

  Future<void> _startNfcInListening() async {
    _nfcHardwareStatus = await _nfcService.checkAvailability();
    _notifySafely();
    if (_nfcHardwareStatus == NfcHardwareStatus.available &&
        _state == TerminalState.listening) {
      await _nfcService.startListening(
        onTagRead: onNfcTagRead,
        onError: (msg) {
          _statusMessage = msg;
          _notifySafely();
        },
      );
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(seconds: _config.inactivityTimeoutSeconds),
      () {
        if (_state == TerminalState.listening) {
          _enterIdleState();
        }
      },
    );
  }

  // ───────────── QR Code Rotativo (US-07, US-08) ─────────────

  void _startQrPolling() {
    _qrRefreshTimer?.cancel();
    _qrExpiryGuardTimer?.cancel();
    unawaited(refreshQrCodeNow());
    _qrRefreshTimer = Timer.periodic(qrRefreshInterval, (_) {
      if (_state == TerminalState.listening) {
        unawaited(refreshQrCodeNow());
      }
    });
  }

  /// Busca um novo token QR no backend; em falha, invalida imediatamente o QR atual (US-08).
  Future<void> refreshQrCodeNow() async {
    if (_state != TerminalState.listening) return;
    try {
      final token = await _apiClient.fetchQrToken();
      if (_state != TerminalState.listening) return;
      _currentQrToken = token;
      _qrUnavailable = false;
      _scheduleQrExpiryGuard(token);
      _notifySafely();
    } catch (_) {
      if (_state != TerminalState.listening) return;
      // Nunca mantém um token expirado/desatualizado na tela (US-08)
      _currentQrToken = null;
      _qrUnavailable = true;
      _notifySafely();
    }
  }

  void _scheduleQrExpiryGuard(QrToken token) {
    _qrExpiryGuardTimer?.cancel();
    final remaining = token.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _currentQrToken = null;
      _qrUnavailable = true;
      return;
    }
    _qrExpiryGuardTimer = Timer(remaining, () {
      if (_currentQrToken == token && token.isExpired()) {
        _currentQrToken = null;
        _qrUnavailable = true;
        _notifySafely();
      }
    });
  }

  // ───────────── Leitura e Validação de Credenciais (US-09, US-10, US-11, US-12) ─────────────

  /// Chamado quando uma tag NFC é aproximada do terminal em Escuta (US-09, US-10).
  Future<void> onNfcTagRead(String rawUid) async {
    if (_state != TerminalState.listening) return;

    String normalizedUid;
    try {
      normalizedUid = NfcUidHelper.normalizeHexUid(rawUid);
    } catch (_) {
      _statusMessage = 'Formato de tag NFC inválido.';
      _notifySafely();
      return;
    }

    // Respeita o intervalo mínimo entre envios para evitar registros duplicados (US-10)
    if (!_nfcCooldownGuard.shouldAccept(normalizedUid)) {
      return;
    }

    await _processCredentialValidation(
      () => _apiClient.validateNfcAccess(normalizedUid),
    );
  }

  /// Chamado quando o módulo facial (US-18) identifica um usuário acima do limiar.
  Future<void> onFaceIdentified({
    required String userId,
    required double confidence,
  }) async {
    if (_state != TerminalState.listening) return;
    if (confidence < _config.faceSimilarityThreshold) return;

    await _processCredentialValidation(
      () => _apiClient.validateFaceAccess(
        userId: userId,
        confidence: confidence,
      ),
    );
  }

  Future<void> _processCredentialValidation(
    Future<AccessResult> Function() validationCall,
  ) async {
    _cancelOperationalTimers();
    await _nfcService.stopListening();

    _state = TerminalState.validating;
    _statusMessage = null;
    _notifySafely();

    final result = await validationCall();
    if (_disposed) return;

    _lastAccessResult = result;

    if (result.isGranted) {
      // Estado Liberado -> volta para Repouso após resultDisplayDuration (US-04, US-11)
      _state = TerminalState.granted;
      _notifySafely();
      _resultReturnTimer = Timer(resultDisplayDuration, () {
        if (_state == TerminalState.granted) {
          _enterIdleState();
        }
      });
    } else {
      // Estado Negado (ou indisponível US-12) -> volta para Escuta após resultDisplayDuration (US-04, US-11)
      _state = TerminalState.denied;
      _notifySafely();
      _resultReturnTimer = Timer(resultDisplayDuration, () {
        if (_state == TerminalState.denied) {
          _enterListeningState();
        }
      });
    }
  }

  void _cancelOperationalTimers() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = null;
    _qrExpiryGuardTimer?.cancel();
    _qrExpiryGuardTimer = null;
    _resultReturnTimer?.cancel();
    _resultReturnTimer = null;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelOperationalTimers();
    _stopPresenceFallbackPolling();
    unawaited(_nfcService.stopListening());
    unawaited(_mqttService.disconnect());
    super.dispose();
  }
}
