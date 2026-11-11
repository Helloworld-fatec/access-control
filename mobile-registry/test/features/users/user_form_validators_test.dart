import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/users/data/user_models.dart';
import 'package:mobile_registry/features/users/presentation/user_form_validators.dart';

void main() {
  group('nome', () {
    test('obrigatório', () {
      for (final v in [null, '', '   ']) {
        expect(UserFormValidators.name(v), 'Informe o nome completo.');
      }
    });

    test('mínimo de 2 letras (igual ao backend)', () {
      expect(UserFormValidators.name('A'), contains('muito curto'));
      expect(UserFormValidators.name('Al'), isNull);
      expect(UserFormValidators.name('  Ana  '), isNull);
    });

    test('máximo de 120', () {
      expect(UserFormValidators.name('a' * 120), isNull);
      expect(UserFormValidators.name('a' * 121), contains('muito longo'));
    });
  });

  group('e-mail', () {
    test('obrigatório e com formato válido', () {
      expect(UserFormValidators.email(''), 'Informe o e-mail.');
      expect(UserFormValidators.email(null), 'Informe o e-mail.');
      for (final v in ['ana', 'ana@', '@x.com', 'a@b', 'a b@c.com']) {
        expect(UserFormValidators.email(v), contains('E-mail inválido'), reason: v);
      }
      for (final v in ['ana@teste.com', ' ANA@Teste.com.br ', 'a.b+c@d.io']) {
        expect(UserFormValidators.email(v), isNull, reason: v);
      }
    });
  });

  group('documento e telefone (opcionais)', () {
    test('em branco vale', () {
      expect(UserFormValidators.document(null), isNull);
      expect(UserFormValidators.document('  '), isNull);
      expect(UserFormValidators.phone(''), isNull);
    });

    test('respeitam os limites do backend (30 e 20)', () {
      expect(UserFormValidators.document('1' * 30), isNull);
      expect(UserFormValidators.document('1' * 31), contains('no máximo 30'));
      expect(UserFormValidators.phone('1' * 20), isNull);
      expect(UserFormValidators.phone('1' * 21), contains('no máximo 20'));
    });
  });

  group('senha', () {
    test('obrigatória no cadastro', () {
      expect(UserFormValidators.password('', required: true), 'Informe a senha.');
      expect(UserFormValidators.password(null, required: true), 'Informe a senha.');
    });

    test('opcional na edição (em branco = manter)', () {
      expect(UserFormValidators.password('', required: false), isNull);
      expect(UserFormValidators.password(null, required: false), isNull);
    });

    test('mínimo de 6 e máximo de 72, nos dois modos', () {
      for (final required in [true, false]) {
        expect(UserFormValidators.password('12345', required: required), contains('ao menos 6'));
        expect(UserFormValidators.password('123456', required: required), isNull);
        expect(UserFormValidators.password('a' * 72, required: required), isNull);
        expect(UserFormValidators.password('a' * 73, required: required), contains('no máximo 72'));
      }
    });

    test('espaços fazem parte da senha', () {
      expect(UserFormValidators.password('      ', required: true), isNull);
    });
  });

  group('perfil', () {
    test('obrigatório', () {
      expect(UserFormValidators.role(null), 'Escolha o perfil.');
      for (final role in UserRole.values) {
        expect(UserFormValidators.role(role), isNull);
      }
    });
  });

  group('keepFilled (o backend ignora opcional em branco no PUT)', () {
    test('avisa quando se tenta apagar um valor existente', () {
      expect(
        UserFormValidators.keepFilled('', original: '123'),
        contains('Não é possível apagar'),
      );
      expect(UserFormValidators.keepFilled('   ', original: '123'), isNotNull);
    });

    test('aceita trocar o valor, manter ou deixar vazio quando já era vazio', () {
      expect(UserFormValidators.keepFilled('456', original: '123'), isNull);
      expect(UserFormValidators.keepFilled('123', original: '123'), isNull);
      expect(UserFormValidators.keepFilled('', original: null), isNull);
      expect(UserFormValidators.keepFilled('', original: ''), isNull);
    });
  });
}
