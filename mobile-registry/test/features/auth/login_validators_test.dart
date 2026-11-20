import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/auth/presentation/login_validators.dart';

void main() {
  group('e-mail', () {
    test('aceita formatos válidos', () {
      for (final v in ['admin@teste.com', 'a.b+c@dominio.com.br', '  x@y.io  ']) {
        expect(LoginValidators.email(v), isNull, reason: v);
      }
    });

    test('vazio pede o e-mail', () {
      expect(LoginValidators.email(''), 'Informe o e-mail.');
      expect(LoginValidators.email('   '), 'Informe o e-mail.');
      expect(LoginValidators.email(null), 'Informe o e-mail.');
    });

    test('rejeita formatos inválidos', () {
      for (final v in ['admin', 'admin@', '@teste.com', 'a@b', 'a b@c.com', 'a@@b.com']) {
        expect(
          LoginValidators.email(v),
          'E-mail inválido. Exemplo: nome@exemplo.com.',
          reason: v,
        );
      }
    });
  });

  group('senha', () {
    test('vazia pede a senha', () {
      expect(LoginValidators.password(''), 'Informe a senha.');
      expect(LoginValidators.password(null), 'Informe a senha.');
    });

    test('qualquer texto não vazio vale, inclusive só espaços', () {
      expect(LoginValidators.password('abc'), isNull);
      expect(LoginValidators.password('   '), isNull);
    });
  });
}
