/// Validações do formulário de login (mensagens em linguagem simples).
abstract final class LoginValidators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _octet = RegExp(r'^(0|[1-9][0-9]{0,2})$');
  static final RegExp _digits = RegExp(r'^[0-9]+$');

  static String? serverIp(String? value) {
    final parts = (value ?? '').trim().split('.');
    if (parts.length != 4 ||
        !parts.every(
          (part) => _octet.hasMatch(part) && int.parse(part) <= 255,
        )) {
      return 'Informe um IPv4 válido, como 192.168.1.25.';
    }
    return null;
  }

  static String? serverPort(String? value) {
    final text = (value ?? '').trim();
    final port = _digits.hasMatch(text) ? int.tryParse(text) : null;
    if (port == null || port < 1 || port > 65535) {
      return 'Informe uma porta entre 1 e 65535.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe o e-mail.';
    if (!_email.hasMatch(text)) {
      return 'E-mail inválido. Exemplo: nome@exemplo.com.';
    }
    return null;
  }

  /// A senha não é aparada nem alterada: espaços fazem parte dela.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Informe a senha.';
    return null;
  }
}
