import '../data/user_models.dart';

/// Validações básicas do formulário de usuário (US-08).
///
/// São só conferências de preenchimento e formato, iguais às do backend para
/// o que é óbvio. Regras de negócio (e-mail ou documento já cadastrado)
/// são do backend: o app apenas mostra a resposta.
abstract final class UserFormValidators {
  static const int minNameLength = 2;
  static const int maxNameLength = 120;
  static const int maxDocumentLength = 30;
  static const int maxPhoneLength = 20;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 72;

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe o nome completo.';
    if (text.length < minNameLength) {
      return 'Nome muito curto. Use ao menos $minNameLength letras.';
    }
    if (text.length > maxNameLength) {
      return 'Nome muito longo. Use no máximo $maxNameLength letras.';
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

  static String? document(String? value) =>
      _maxLength(value, maxDocumentLength, 'documento');

  static String? phone(String? value) =>
      _maxLength(value, maxPhoneLength, 'telefone');

  static String? _maxLength(String? value, int max, String label) {
    if ((value ?? '').trim().length > max) {
      return 'O $label aceita no máximo $max caracteres.';
    }
    return null;
  }

  /// Senha. Obrigatória ao cadastrar; na edição é opcional (em branco = manter).
  static String? password(String? value, {required bool required}) {
    final text = value ?? '';
    if (text.isEmpty) return required ? 'Informe a senha.' : null;
    if (text.length < minPasswordLength) {
      return 'A senha deve ter ao menos $minPasswordLength caracteres.';
    }
    if (text.length > maxPasswordLength) {
      return 'A senha deve ter no máximo $maxPasswordLength caracteres.';
    }
    return null;
  }

  static String? role(UserRole? value) =>
      value == null ? 'Escolha o perfil.' : null;

  /// O backend ignora campo opcional em branco no `PUT`: não dá para apagar
  /// um documento ou telefone já informado. Avisamos em vez de fingir que apagou.
  static String? keepFilled(String? value, {required String? original}) {
    final hadValue = (original ?? '').trim().isNotEmpty;
    if (hadValue && (value ?? '').trim().isEmpty) {
      return 'Não é possível apagar este campo por aqui. '
          'Digite o novo valor.';
    }
    return null;
  }
}
