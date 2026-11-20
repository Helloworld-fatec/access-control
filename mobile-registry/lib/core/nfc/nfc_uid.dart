/// Padronização do UID de tags NFC, igual à do mobile-readings e do backend:
/// hexadecimal em maiúsculas, sem separadores, sempre na mesma ordem de bytes.
///
/// O backend aceita de 8 a 20 caracteres hexadecimais (4 a 10 bytes).
abstract final class NfcUid {
  static const int minLength = 8;
  static const int maxLength = 20;

  static final RegExp _valid = RegExp(r'^[0-9A-F]+$');

  /// Bytes do identificador -> "04A32F1B". Mantém a ordem recebida.
  static String formatBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Lista de bytes do UID NFC não pode ser vazia.');
    }
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write((byte & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }

  /// Texto digitado ou colado ("04:a3:2f:1b", "04 a3 2f 1b") -> "04A32F1B".
  /// Lança [FormatException] se não for um UID válido.
  static String normalize(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s:-]'), '').toUpperCase();
    if (!isValid(cleaned)) {
      throw const FormatException(
        'Código inválido. Use de 8 a 20 caracteres hexadecimais '
        '(números de 0 a 9 e letras de A a F).',
      );
    }
    return cleaned;
  }

  /// `null` se o texto não for um UID válido.
  static String? tryNormalize(String raw) {
    try {
      return normalize(raw);
    } on FormatException {
      return null;
    }
  }

  /// UID já padronizado e dentro dos limites do backend (número par de dígitos).
  static bool isValid(String uid) =>
      uid.length >= minLength &&
      uid.length <= maxLength &&
      uid.length.isEven &&
      _valid.hasMatch(uid);

  /// Extrai os bytes do identificador do mapa de dados de um `NfcTag`
  /// (`tag.data` do nfc_manager).
  static List<int>? extractIdentifier(Map<String, dynamic> data) {
    for (final tech in const [
      'nfca',
      'isodep',
      'mifareclassic',
      'mifareultralight',
      'nfcb',
      'nfcf',
      'nfcv',
    ]) {
      final entry = data[tech];
      if (entry is Map && entry['identifier'] is List) {
        return List<int>.from(entry['identifier'] as List);
      }
    }
    if (data['identifier'] is List) {
      return List<int>.from(data['identifier'] as List);
    }
    return null;
  }
}
