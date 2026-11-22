import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/terminal_config.dart';
import '../models/access_result.dart';
import '../models/qr_token.dart';
import '../services/accessibility_service.dart';
import '../services/api_client.dart';

enum TerminalState {
  idle,
  choosing,
  qr,
  facial,
  validatingFacial,
  facialResult
}

class TerminalController extends ChangeNotifier {
  final ConfigStorage _configStorage;
  final TerminalApiClient _apiClient;
  static const _qrFailureDelay = Duration(seconds: 10);
  static const _presencePollDelay = Duration(seconds: 2);

  TerminalConfig _config = const TerminalConfig();
  TerminalState _state = TerminalState.idle;
  QrToken? _currentQrToken;
  AccessResult? _facialResult;
  String? _qrError;
  DateTime? _qrRetryAt;
  bool _qrKeyRejected = false;
  Future<void>? _qrRequest;
  bool _qrLoading = false;
  bool _capturing = false;
  bool _initialized = false;
  bool _disposed = false;
  bool _presenceDetected = false;
  int _operationGeneration = 0;

  Timer? _inactivityTimer;
  Timer? _qrRefreshTimer;
  Timer? _qrExpiryTimer;
  Timer? _presenceTimer;

  TerminalController({
    required ConfigStorage configStorage,
    required TerminalApiClient apiClient,
  })  : _configStorage = configStorage,
        _apiClient = apiClient;

  TerminalConfig get config => _config;
  TerminalState get state => _state;
  QrToken? get currentQrToken => _currentQrToken;
  AccessResult? get facialResult => _facialResult;
  String? get qrError => _qrError;
  bool get canRetryQr =>
      !_qrLoading && !_qrKeyRejected && _qrCooldown <= Duration.zero;
  bool get isQrLoading => _qrLoading;
  bool get isCapturing => _capturing;
  bool get initialized => _initialized;

  AccessibilityService get _accessibility => AccessibilityService(
        enabled: _config.voiceAccessibilityEnabled,
      );

  Future<void> initialize() async {
    final config = await _configStorage.load();
    if (_disposed) return;
    _config = config;
    _apiClient.updateConfig(config);
    _initialized = true;
    _schedulePresencePoll();
    notifyListeners();
  }

  Future<void> configureTerminal(String address, String key) async {
    final normalized = TerminalConfig.normalizeServerAddress(address);
    if (normalized == null || TerminalConfig.validateTerminalKey(key) != null) {
      throw const TerminalApiException(
        'Confira o endereço e a chave do terminal.',
      );
    }
    final candidate = _config.copyWith(
      serverAddress: normalized,
      apiKey: key.trim().toLowerCase(),
    );
    final id = await _apiClient.identifyTerminal(candidate);
    if (_disposed) return;
    final verified = candidate.copyWith(terminalId: id);
    await _configStorage.save(verified);
    if (_disposed) return;

    _qrKeyRejected = false;
    _qrRetryAt = null;
    _presenceDetected = false;
    _config = verified;
    _apiClient.updateConfig(verified);
    returnToIdle();
  }

  void activate() {
    if (_state != TerminalState.idle || !_config.isConfigured) {
      return;
    }
    showChoices();
    unawaited(_accessibility.notifyTerminalAwake());
  }

  void showChoices() => _enter(TerminalState.choosing);

  void showQr() {
    if (_state == TerminalState.qr) return;
    _enter(TerminalState.qr);
    unawaited(refreshQrCodeNow());
  }

  void showFacial() => _enter(TerminalState.facial);

  void returnToIdle() => _enter(TerminalState.idle);

  void _enter(TerminalState next) {
    _operationGeneration++;
    _cancelTimers();
    _state = next;
    _currentQrToken = null;
    _facialResult = null;
    _qrError = null;
    _qrLoading = false;
    _capturing = false;
    if (next == TerminalState.choosing || next == TerminalState.facial) {
      _resetInactivityTimer();
    }
    if (next == TerminalState.idle) _schedulePresencePoll();
    notifyListeners();
  }

  void _schedulePresencePoll([Duration delay = _presencePollDelay]) {
    if (!_config.isConfigured || _disposed || _state != TerminalState.idle) return;
    _presenceTimer?.cancel();
    final generation = _operationGeneration;
    _presenceTimer = Timer(delay, () async {
      var nextDelay = _presencePollDelay;
      try {
        final detected = await _apiClient.fetchPresence();
        if (!_isCurrent(generation)) return;
        final justDetected = detected && !_presenceDetected;
        _presenceDetected = detected;
        if (justDetected) activate();
      } on Exception {
        nextDelay = _qrFailureDelay;
      }
      if (_isCurrent(generation)) _schedulePresencePoll(nextDelay);
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(seconds: _config.inactivityTimeoutSeconds),
      returnToIdle,
    );
  }

  Duration get _qrCooldown =>
      _qrRetryAt?.difference(DateTime.now()) ?? Duration.zero;

  void _scheduleQrRefresh(Duration delay) {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer(delay, () => unawaited(refreshQrCodeNow()));
  }

  Future<void> refreshQrCodeNow() async {
    if (_state != TerminalState.qr || _qrLoading) return;
    final generation = _operationGeneration;
    _qrRefreshTimer?.cancel();

    _qrLoading = true;
    notifyListeners();
    try {
      // Uma troca de tela invalida o resultado da emissão anterior. Aguarde
      // essa requisição terminar antes de emitir outro token.
      final previous = _qrRequest;
      if (previous != null) await previous;
      if (!_isCurrent(generation)) return;

      if (_qrKeyRejected) {
        _qrError = 'Chave do terminal rejeitada. Confira a configuração.';
        return;
      }
      final cooldown = _qrCooldown;
      if (cooldown > Duration.zero) {
        _qrError = 'Limite de emissão atingido. Aguarde para tentar novamente.';
        _scheduleQrRefresh(cooldown);
        return;
      }

      final config = _config;
      final request = Completer<void>();
      _qrRequest = request.future;
      try {
        final token = await _apiClient.fetchQrToken();
        if (!_isCurrent(generation)) return;
        _showQrToken(token);
        _scheduleQrRefresh(Duration(seconds: token.refreshAfterSeconds));
      } on Exception catch (error) {
        if (!identical(config, _config)) return;
        if (error is TerminalApiException) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            _qrKeyRejected = true;
          } else if (error.statusCode == 429) {
            _qrRetryAt =
                DateTime.now().add(error.retryAfter ?? _qrFailureDelay);
          }
        }
        if (!_isCurrent(generation)) return;
        if (_qrKeyRejected) {
          _qrExpiryTimer?.cancel();
          _currentQrToken = null;
          _qrError = 'Chave do terminal rejeitada. Confira a configuração.';
        } else if (_qrCooldown > Duration.zero) {
          _qrError =
              'Limite de emissão atingido. Aguarde para tentar novamente.';
          _scheduleQrRefresh(_qrCooldown);
        } else {
          _qrError = 'Falha ao atualizar o QR Code. Confira a conexão.';
          _scheduleQrRefresh(_qrFailureDelay);
        }
      } finally {
        _qrRequest = null;
        request.complete();
      }
    } finally {
      if (_isCurrent(generation)) {
        _qrLoading = false;
        notifyListeners();
      }
    }
  }

  void _showQrToken(QrToken token) {
    _qrExpiryTimer?.cancel();
    final remaining = token.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _currentQrToken = null;
      _qrError = 'QR Code expirado. Tente novamente.';
      return;
    }

    _currentQrToken = token;
    _qrError = null;
    _qrExpiryTimer = Timer(remaining, () {
      _currentQrToken = null;
      _qrError ??= 'QR Code expirado. Tente novamente.';
      notifyListeners();
    });
  }

  Future<void> startRecognition(
    Future<List<List<int>>> Function() capture,
  ) async {
    if (_state != TerminalState.facial || _capturing) return;
    final generation = _operationGeneration;
    _capturing = true;
    _inactivityTimer?.cancel();
    notifyListeners();

    late final List<List<int>> photos;
    try {
      photos = await capture().timeout(const Duration(seconds: 10));
    } on Exception {
      if (_isCurrent(generation)) cameraUnavailable();
      return;
    }

    if (!_isCurrent(generation)) return;
    if (photos.isEmpty) {
      _showFacialResult(AccessResult.unavailable(
        'A câmera precisa produzir imagens JPEG de até 100 KB.',
      ));
      return;
    }

    _capturing = false;
    _state = TerminalState.validatingFacial;
    notifyListeners();
    final result = await _apiClient.recognizeFace(photos);
    if (_isCurrent(generation)) _showFacialResult(result);
  }

  void cameraUnavailable() {
    if (_state != TerminalState.facial) return;
    _showFacialResult(
      AccessResult.unavailable(
          'Câmera frontal indisponível. Confira a permissão da câmera.'),
    );
  }

  void _showFacialResult(AccessResult result) {
    _operationGeneration++;
    _capturing = false;
    _facialResult = result;
    _state = TerminalState.facialResult;
    _resetInactivityTimer();
    notifyListeners();
    if (result.isGranted) {
      unawaited(_accessibility.notifyAccessGranted(result.userName));
    } else {
      unawaited(_accessibility.notifyAccessDenied(result.message));
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _operationGeneration;

  void _cancelTimers() {
    _inactivityTimer?.cancel();
    _qrRefreshTimer?.cancel();
    _qrExpiryTimer?.cancel();
    _presenceTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
