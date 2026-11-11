/// Validações dos campos da tela de configuração.
/// Retornam `null` quando válido, ou a mensagem (linguagem simples) de erro.
abstract final class SettingsValidators {
  static const int minPhotoKb = 10;
  static const int maxPhotoKb = 500;
  static const int minFaceSamples = 3;
  static const int maxFaceSamples = 5;

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  static bool isValidIPv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      if (part.isEmpty || part.length > 3 || !_digits.hasMatch(part)) {
        return false;
      }
      if (int.parse(part) > 255) return false;
    }
    return true;
  }

  static String? host(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe o endereço do servidor.';
    if (!isValidIPv4(text)) {
      return 'Endereço inválido. Use o formato 192.168.0.10.';
    }
    return null;
  }

  static String? port(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe a porta do servidor.';
    final number = _digits.hasMatch(text) ? int.tryParse(text) : null;
    if (number == null || number < 1 || number > 65535) {
      return 'Porta inválida. Use um número de 1 a 65535.';
    }
    return null;
  }

  static String? photoKb(String? value) {
    final text = (value ?? '').trim();
    const message =
        'Informe um tamanho entre $minPhotoKb e $maxPhotoKb KB.';
    if (text.isEmpty) return message;
    final number = _digits.hasMatch(text) ? int.tryParse(text) : null;
    if (number == null || number < minPhotoKb || number > maxPhotoKb) {
      return message;
    }
    return null;
  }

  static String? faceSamples(int? value) {
    if (value == null ||
        value < minFaceSamples ||
        value > maxFaceSamples) {
      return 'Escolha de $minFaceSamples a $maxFaceSamples capturas.';
    }
    return null;
  }
}
