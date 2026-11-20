/// Validações do formulário de login (mensagens em linguagem simples).
abstract final class LoginValidators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
