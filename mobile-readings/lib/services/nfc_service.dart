import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';

/// Utilitário puro de padronização e controle de frequência de leitura NFC (US-09, US-10).
class NfcUidHelper {
  /// Converte bytes brutos do UID para hexadecimal em maiúsculas, sem separadores,
  /// mantendo sempre a mesma ordem de bytes (padrão compartilhado com mobile-registry e backend).
  static String formatUidBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Lista de bytes do UID NFC não pode ser vazia.');
    }
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }

  /// Normaliza uma string hexadecimal arbitrária (ex.: "04:a1:b2:c3" -> "04A1B2C3").
  static String normalizeHexUid(String rawUid) {
    final cleaned = rawUid.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (cleaned.length < 8 || cleaned.length > 32 || cleaned.length.isOdd) {
      throw const FormatException(
        'UID NFC deve conter entre 4 e 16 bytes em hexadecimal.',
      );
    }
    return cleaned;
  }

  /// Extrai a lista de bytes do identificador a partir do mapa de dados do NfcTag.
  static List<int>? extractIdentifierFromTagData(Map<String, dynamic> data) {
    for (final techKey in ['nfca', 'isodep', 'mifareclassic', 'mifareultralight', 'nfcb', 'nfcf', 'nfcv']) {
      final tech = data[techKey];
      if (tech is Map && tech['identifier'] is List) {
        return List<int>.from(tech['identifier'] as List);
      }
    }
    // Fallback caso o identifier esteja na raiz do mapa
    if (data['identifier'] is List) {
      return List<int>.from(data['identifier'] as List);
    }
    return null;
  }
}

/// Controlador de intervalo mínimo (cooldown) entre leituras NFC para evitar envios duplicados (US-10).
class NfcCooldownGuard {
  final Duration minInterval;
  DateTime? _lastAcceptedAt;
  String? _lastUid;

  NfcCooldownGuard({
    this.minInterval = const Duration(seconds: 3),
  });

  /// Retorna `true` se a leitura puder prosseguir; `false` se estiver dentro da janela de bloqueio.
  bool shouldAccept(String uid, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (_lastAcceptedAt != null) {
      final elapsed = current.difference(_lastAcceptedAt!);
      if (elapsed < minInterval) {
        return false;
      }
    }
    _lastAcceptedAt = current;
    _lastUid = uid;
    return true;
  }

  String? get lastUid => _lastUid;

  void reset() {
    _lastAcceptedAt = null;
    _lastUid = null;
  }
}

/// Estado do hardware NFC no dispositivo (US-09).
enum NfcHardwareStatus {
  available,
  disabledOrUnavailable,
  unsupportedPlatform,
}

/// Interface do serviço NFC para permitir mock em testes unitários/widget.
abstract class NfcReaderService {
  Future<NfcHardwareStatus> checkAvailability();
  Future<void> startListening({
    required void Function(String uid) onTagRead,
    void Function(String errorMessage)? onError,
  });
  Future<void> stopListening();
}

/// Implementação usando a API NFC nativa via nfc_manager (US-09, US-13).
class NativeNfcReaderService implements NfcReaderService {
  bool _sessionActive = false;

  bool get isSessionActive => _sessionActive;

  @override
  Future<NfcHardwareStatus> checkAvailability() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      return available
          ? NfcHardwareStatus.available
          : NfcHardwareStatus.disabledOrUnavailable;
    } catch (_) {
      return NfcHardwareStatus.unsupportedPlatform;
    }
  }

  @override
  Future<void> startListening({
    required void Function(String uid) onTagRead,
    void Function(String errorMessage)? onError,
  }) async {
    final status = await checkAvailability();
    if (status != NfcHardwareStatus.available) {
      return;
    }
    if (_sessionActive) return;

    try {
      _sessionActive = true;
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final bytes = NfcUidHelper.extractIdentifierFromTagData(tag.data);
            if (bytes == null || bytes.isEmpty) {
              onError?.call('Não foi possível ler o identificador da tag NFC.');
              return;
            }
            final uid = NfcUidHelper.formatUidBytes(Uint8List.fromList(bytes));
            onTagRead(uid);
          } catch (e) {
            onError?.call('Falha ao processar a tag NFC.');
          }
        },
      );
    } catch (_) {
      _sessionActive = false;
      onError?.call('Não foi possível iniciar o leitor NFC.');
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
