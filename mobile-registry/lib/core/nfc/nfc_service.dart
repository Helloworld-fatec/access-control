import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'nfc_uid.dart';

/// Situação do NFC no aparelho.
enum NfcHardwareStatus {
  /// Pronto para ler.
  available,

  /// O aparelho não tem NFC ou ele está desligado (a API do Android não
  /// distingue os dois casos).
  disabledOrUnavailable,

  /// Plataforma sem suporte a NFC (ex.: emulador, computador).
  unsupportedPlatform,
}

/// Falha na leitura de uma tag, com mensagem pronta para a tela.
class NfcReadException implements Exception {
  const NfcReadException(this.message, {this.cancelled = false});

  final String message;

  /// A leitura foi cancelada pelo próprio app (não é um erro a exibir).
  final bool cancelled;

  @override
  String toString() => 'NfcReadException($message)';
}

/// Contrato do leitor NFC. Existe para os testes usarem um leitor falso.
abstract interface class NfcService {
  Future<NfcHardwareStatus> checkAvailability();

  /// Espera o usuário aproximar UMA tag e devolve o UID padronizado.
  /// Lança [NfcReadException] em caso de falha, tempo esgotado ou cancelamento.
  Future<String> readUid({Duration timeout});

  /// Interrompe uma leitura em andamento.
  Future<void> cancel();
}

/// Leitor real, usando a API NFC nativa do Android via `nfc_manager`.
class NativeNfcService implements NfcService {
  Completer<String>? _pending;

  @override
  Future<NfcHardwareStatus> checkAvailability() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return switch (availability) {
        NfcAvailability.enabled => NfcHardwareStatus.available,
        NfcAvailability.disabled ||
        NfcAvailability.unsupported =>
          NfcHardwareStatus.disabledOrUnavailable,
      };
    } catch (_) {
      return NfcHardwareStatus.unsupportedPlatform;
    }
  }

  @override
  Future<String> readUid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await cancel(); // começa sempre com a sessão limpa

    final completer = Completer<String>();
    _pending = completer;

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) {
          if (completer.isCompleted) return;
          try {
            // nfc_manager 4.x: `tag.data` é protegido. O UID é lido pela
            // classe específica da plataforma (Android), via `NfcTagAndroid`.
            final bytes = NfcTagAndroid.from(tag)?.id;
            if (bytes == null || bytes.isEmpty) {
              completer.completeError(const NfcReadException(
                'Não foi possível ler o código desta tag. Tente outra tag.',
              ));
              return;
            }
            completer.complete(NfcUid.formatBytes(bytes));
          } catch (_) {
            completer.completeError(
              const NfcReadException('Falha ao processar a tag NFC.'),
            );
          }
        },
      );
    } catch (_) {
      _pending = null;
      throw const NfcReadException('Não foi possível iniciar o leitor NFC.');
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw const NfcReadException(
          'Tempo esgotado. Aproxime a tag e tente de novo.',
        ),
      );
    } finally {
      _pending = null;
      await _stopSession();
    }
  }

  @override
  Future<void> cancel() async {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(
        const NfcReadException('Leitura cancelada.', cancelled: true),
      );
    }
    await _stopSession();
  }

  Future<void> _stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Sem sessão ativa: nada a fazer.
    }
  }
}

/// Leitor NFC do app. Os testes sobrescrevem com um leitor falso.
final nfcServiceProvider = Provider<NfcService>((ref) => NativeNfcService());