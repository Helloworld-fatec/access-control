import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/terminal_config.dart';
import '../models/access_result.dart';
import '../models/qr_token.dart';
import '../services/api_client.dart';
import '../services/face_sync_service.dart';
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
  final FaceSyncService _faceService;
  final NfcCooldownGuard _nfcCooldownGuard;

  final Duration qrRefreshInterval;
  final Duration presencePollingInterval;
  final Duration resultDisplayDuration;

  TerminalConfig _config;
  TerminalState _state = TerminalState.idle;
  QrToken? _currentQrToken;
  bool _qrUnavailable = false;
  bool _mqttConnected = false;
  bool _isFaceSyncLoading = false;
  bool _faceModeEnabled = false;
  bool _isReaderBusy = false;
  String? _faceSyncMessage;
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
    FaceSyncService? faceService,
    NfcCooldownGuard? nfcCooldownGuard,
    TerminalConfig initialConfig = const TerminalConfig(),
    this.qrRefreshInterval = const Duration(seconds: 10),
    this.presencePollingInterval = const Duration(seconds: 2),
    this.resultDisplayDuration = const Duration(seconds: 3),
  })  : _configStorage = configStorage,
        _apiClient = apiClient,
        _nfcService = nfcService,
        _mqttService = mqttService,
        _faceService = faceService ?? FaceSyncService(),
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
  bool get isReaderBusy => _isReaderBusy;
  FaceSyncService get faceService => _faceService;
  int get faceEmbeddingsCount => _faceService.authorizedEmbeddings.length;
  bool get isFaceSyncLoading => _isFaceSyncLoading;
  String? get faceSyncMessage => _faceSyncMessage;
  bool get isFaceModeEnabled => _faceModeEnabled;

  void setFaceMode(bool enabled) {
    if (_faceModeEnabled != enabled) {
      _faceModeEnabled = enabled;
      _notifySafely();
    }
  }

  /// Indica se o leitor NFC está ocupado para gravação remota de tag (US-10).
  void setReaderBusy(bool busy) {
    if (_isReaderBusy != busy) {
      _isReaderBusy = busy;
      _notifySafely();
    }
  }

  // ───────────── Inicialização e Configuração ─────────────

  Future<void> initialize() async {
    _config = await _configStorage.load();
    _apiClient.updateConfig(_config);
    _nfcHardwareStatus = await _nfcService.checkAvailability();
    _notifySafely();
    await _connectPresenceChannels();
    unawaited(syncFaceEmbeddings());
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
    unawaited(syncFaceEmbeddings());
    _notifySafely();
  }

  /// Sincroniza templates biométricos autorizados para cache volátil em RAM (US-15).
  Future<int> syncFaceEmbeddings() async {
    if (_config.simulationMode) {
      _faceSyncMessage = 'Modo Simulação: Biometria em memória simulada.';
      _notifySafely();
      return _faceService.authorizedEmbeddings.length;
    }

    _isFaceSyncLoading = true;
    _faceSyncMessage = null;
    _notifySafely();

    try {
      final count = await _faceService.syncEmbeddings(_config);
      _faceSyncMessage = '$count biometrias autorizadas em memória RAM.';
      _isFaceSyncLoading = false;
      _notifySafely();
      return count;
    } catch (e) {
      _faceSyncMessage = 'Falha ao sincronizar biometrias: $e';
      _isFaceSyncLoading = false;
      _notifySafely();
      return _faceService.authorizedEmbeddings.length;
    }
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
    if (confidence < _config.faceSimilarityThreshold) {
      _statusMessage =
          'Similaridade insuficiente: ${(confidence * 100).toStringAsFixed(1)}% (limiar: ${(_config.faceSimilarityThreshold * 100).toStringAsFixed(0)}%)';
      _notifySafely();
      return;
    }

    await _processCredentialValidation(
      () => _apiClient.validateFaceAccess(
        userId: userId,
        confidence: confidence,
      ),
    );
  }

  /// Avalia um vetor facial capturado pela câmera contra o cache volátil em RAM (US-16, US-17, US-19).
  Future<void> evaluateCapturedFace(
    List<double> capturedEmbedding, {
    double lightLevel = 0.8,
  }) async {
    if (_state != TerminalState.listening) return;

    // Alerta de iluminação insuficiente (US-19)
    if (lightLevel < 0.35) {
      _statusMessage =
          'Iluminação insuficiente no enquadramento. Posicione-se sob luz mais clara.';
      _notifySafely();
      return;
    }

    final match = _faceService.findBestMatch(
      capturedEmbedding,
      threshold: _config.faceSimilarityThreshold,
    );

    if (match != null) {
      _statusMessage = null;
      await onFaceIdentified(
        userId: match.userId,
        confidence: match.similarity,
      );
    } else {
      _statusMessage = _faceService.authorizedEmbeddings.isEmpty
          ? 'Nenhum rosto cadastrado no terminal. Sincronize com o backend.'
          : 'Rosto não reconhecido ou limiar insuficiente.';
      _notifySafely();
    }
  }

  /// Simula identificação facial autorizada (US-17, US-18).
  /// Se houver embeddings em memória, calcula o score via cosseno com vetor real.
  Future<void> simulateFaceAccess() async {
    if (_state != TerminalState.listening) return;

    if (_faceService.authorizedEmbeddings.isNotEmpty) {
      final authorized = _faceService.authorizedEmbeddings.first;
      // Gera vetor quase idêntico com similaridade ~0.95
      final simulatedVector = authorized.embedding.map((v) => v * 0.98).toList();
      await evaluateCapturedFace(simulatedVector, lightLevel: 0.85);
      return;
    }

    // Fallback para ambiente sem embeddings sincronizados previamente
    await _processCredentialValidation(
      () => _apiClient.validateFaceAccess(
        userId: 'demo-face-user',
        confidence: 0.94,
      ),
    );
  }

  /// Simula identificação facial de pessoa não cadastrada (rejeição local US-17).
  Future<void> simulateFaceAccessDenied() async {
    if (_state != TerminalState.listening) return;

    if (_faceService.authorizedEmbeddings.isNotEmpty) {
      final vectorSize = _faceService.authorizedEmbeddings.first.embedding.length;
      final unknownVector = List<double>.generate(vectorSize, (i) => i.isEven ? 1.0 : -1.0);
      await evaluateCapturedFace(unknownVector, lightLevel: 0.85);
      return;
    }

    _statusMessage = 'Rosto não cadastrado na base de acesso.';
    _notifySafely();
  }

  /// Simula iluminação insuficiente (US-19).
  void simulateFaceLowLight() {
    if (_state != TerminalState.listening) return;
    _statusMessage =
        'Iluminação insuficiente no enquadramento. Posicione-se sob luz mais clara.';
    _notifySafely();
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
