import 'dart:async';

import 'package:mobile_registry/core/nfc/nfc_service.dart';

/// Leitor NFC falso para testes.
///
/// [script] é a fila de resultados das próximas leituras; cada item é:
/// - `String`: o UID lido;
/// - `NfcReadException`: a leitura falha com esse erro;
/// - `Completer<String>`: a leitura espera o teste completá-lo.
/// Com a fila vazia, a leitura fica esperando para sempre (aparelho "esperando a tag").
class FakeNfcService implements NfcService {
  FakeNfcService({
    this.status = NfcHardwareStatus.available,
    List<Object>? script,
  }) : script = script ?? [];

  NfcHardwareStatus status;
  final List<Object> script;

  int reads = 0;
  int cancels = 0;
  int availabilityChecks = 0;

  @override
  Future<NfcHardwareStatus> checkAvailability() async {
    availabilityChecks++;
    return status;
  }

  @override
  Future<String> readUid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    reads++;
    if (script.isEmpty) return Completer<String>().future;
    final next = script.removeAt(0);
    if (next is NfcReadException) throw next;
    if (next is Completer<String>) return next.future;
    return next as String;
  }

  @override
  Future<void> cancel() async => cancels++;
}
