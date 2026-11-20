import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/users/data/user_models.dart';
import 'package:mobile_registry/features/users/presentation/user_form_model.dart';

const original = UserSummary(
  id: 'u-1',
  name: 'Maria Silva',
  email: 'maria@teste.com',
  role: UserRole.resident,
  active: true,
  document: '123',
  phone: '11999',
);

UserFormModel loaded() => UserFormModel()..fill(original);

ApiException api(ApiErrorKind kind, {String message = 'x', Object? details}) =>
    ApiException(kind: kind, message: message, details: details);

void main() {
  late UserFormModel model;
  tearDown(() => model.dispose());

  group('fill e changesFrom', () {
    test('sem alterações, nada a enviar', () {
      model = loaded();
      expect(model.changesFrom(original), isEmpty);
    });

    test('envia só o que mudou', () {
      model = loaded();
      model.name.text = '  Maria Souza ';
      expect(model.changesFrom(original), {'name': 'Maria Souza'});
    });

    test('e-mail é comparado sem diferenciar maiúsculas e enviado em minúsculas', () {
      model = loaded();
      model.email.text = 'MARIA@teste.com';
      expect(model.changesFrom(original), isEmpty);
      model.email.text = 'Novo@Teste.com';
      expect(model.changesFrom(original), {'email': 'novo@teste.com'});
    });

    test('opcional em branco significa "manter" (o backend ignora)', () {
      model = loaded();
      model.document.text = '';
      model.phone.text = '   ';
      expect(model.changesFrom(original), isEmpty);
    });

    test('documento e telefone novos são enviados', () {
      model = loaded();
      model.document.text = '999';
      model.phone.text = '11888';
      expect(model.changesFrom(original), {'document': '999', 'phone': '11888'});
    });

    test('perfil e senha', () {
      model = loaded();
      model.role = UserRole.admin;
      model.password.text = 'novasenha';
      expect(model.changesFrom(original), {'role': 'ADMIN', 'password': 'novasenha'});
    });
  });

  group('toNewUser e hasData', () {
    test('monta o cadastro com os campos preenchidos', () {
      model = UserFormModel();
      model.name.text = ' Ana ';
      model.email.text = 'ANA@teste.com';
      model.password.text = 'segredo1';
      model.role = UserRole.visitor;
      final json = model.toNewUser().toJson();
      expect(json, {
        'name': 'Ana',
        'email': 'ana@teste.com',
        'password': 'segredo1',
        'role': 'VISITOR',
      });
    });

    test('hasData acompanha o que foi digitado', () {
      model = UserFormModel();
      expect(model.hasData, isFalse);
      model.phone.text = '1';
      expect(model.hasData, isTrue);
    });
  });

  group('applyApiError', () {
    test('validação com detalhes marca os campos e pede para voltar a eles', () {
      model = loaded();
      final r = model.applyApiError(api(
        ApiErrorKind.validation,
        details: [
          {'path': 'email', 'message': 'E-mail inválido (servidor)'},
        ],
      ));
      expect(r.fieldsAffected, isTrue);
      expect(r.message, 'Confira os campos destacados e tente de novo.');
      expect(model.serverErrors, {'email': 'E-mail inválido (servidor)'});
    });

    test('conflito sem documento marca o e-mail', () {
      model = UserFormModel();
      final r = model.applyApiError(
        api(ApiErrorKind.conflict, message: 'E-mail ou documento já cadastrado'),
      );
      expect(r.fieldsAffected, isTrue);
      expect(r.message, 'E-mail ou documento já cadastrado');
      expect(model.serverErrors, {'email': 'E-mail ou documento já cadastrado'});
    });

    test('conflito com documento só traz a mensagem geral', () {
      model = loaded();
      final r = model.applyApiError(api(ApiErrorKind.conflict, message: 'Repetido'));
      expect(r.fieldsAffected, isTrue);
      expect(model.serverErrors, isEmpty);
    });

    test('outros erros não apontam campos', () {
      model = loaded();
      final r = model.applyApiError(api(ApiErrorKind.server, message: 'Falha'));
      expect(r.fieldsAffected, isFalse);
      expect(r.message, 'Falha');
      expect(model.serverErrors, isEmpty);
    });

    test('validação sem detalhes não aponta campos', () {
      model = loaded();
      expect(model.applyApiError(api(ApiErrorKind.validation)).fieldsAffected, isFalse);
    });
  });
}
