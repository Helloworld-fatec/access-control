import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/users/data/user_models.dart';

import '../../helpers/users_fixtures.dart';

void main() {
  group('UserRole', () {
    test('converte os valores da API e traz o nome em português', () {
      expect(UserRole.parse('ADMIN'), UserRole.admin);
      expect(UserRole.parse('RESIDENT').label, 'Condômino');
      expect(UserRole.parse('VISITOR').label, 'Visitante');
      expect(UserRole.admin.label, 'Administrador');
    });

    test('perfil desconhecido é rejeitado', () {
      expect(() => UserRole.parse('ROOT'), throwsFormatException);
      expect(() => UserRole.parse(null), throwsFormatException);
    });
  });

  group('UserSummary.fromJson', () {
    test('lê os campos da listagem', () {
      final u = UserSummary.fromJson(userJson(phone: '11988887777'));
      expect(u.id, 'u-1');
      expect(u.name, 'Maria Silva');
      expect(u.document, '12345678900');
      expect(u.phone, '11988887777');
      expect(u.role, UserRole.resident);
      expect(u.active, isTrue);
    });

    test('tag e rosto ficam "não informados" quando a API não os envia', () {
      final u = UserSummary.fromJson(userJson());
      expect(u.hasFace, isNull);
      expect(u.nfcTagCount, isNull);
      expect(u.hasNfcTag, isNull);
    });

    test('lê tag e rosto quando a API os envia', () {
      final u = UserSummary.fromJson(userJson(hasFace: true, nfcTagCount: 2));
      expect(u.hasFace, isTrue);
      expect(u.nfcTagCount, 2);
      expect(u.hasNfcTag, isTrue);
      expect(UserSummary.fromJson(userJson(nfcTagCount: 0)).hasNfcTag, isFalse);
    });

    test('documento e telefone nulos ou vazios viram null', () {
      expect(UserSummary.fromJson(userJson(document: null)).document, isNull);
      expect(UserSummary.fromJson(userJson(document: '')).document, isNull);
    });

    test('campo obrigatório ausente ou de tipo errado é rejeitado', () {
      for (final key in ['id', 'name', 'email', 'role', 'active']) {
        expect(
          () => UserSummary.fromJson({...userJson()}..remove(key)),
          throwsFormatException,
          reason: 'sem $key',
        );
      }
      expect(() => UserSummary.fromJson({...userJson(), 'active': 'sim'}), throwsFormatException);
      expect(() => UserSummary.fromJson({...userJson(), 'role': 'ROOT'}), throwsFormatException);
    });
  });

  group('UserDetail.fromJson', () {
    test('lê tags, rosto e foto', () {
      final d = UserDetail.fromJson(
        detailJson(hasFace: true, hasPhoto: true, tags: [tagJson(), tagJson(id: 't-2', uid: '04B1C2D3')]),
      );
      expect(d.hasFace, isTrue);
      expect(d.hasPhoto, isTrue);
      expect(d.nfcTags.map((t) => t.uid), ['04A32F1B', '04B1C2D3']);
      // O resumo já reflete tag e rosto do detalhe.
      expect(d.user.nfcTagCount, 2);
      expect(d.user.hasFace, isTrue);
    });

    test('sem nfcTags ou hasFace, a resposta é rejeitada', () {
      expect(() => UserDetail.fromJson({...detailJson()}..remove('nfcTags')), throwsFormatException);
      expect(() => UserDetail.fromJson({...detailJson()}..remove('hasFace')), throwsFormatException);
    });

    test('withTags troca as tags e atualiza a contagem', () {
      final d = UserDetail.fromJson(detailJson(tags: [tagJson()], hasFace: true));
      final updated = d.withTags([
        const NfcTag(id: 't-9', uid: '04B1C2D3', active: true),
        const NfcTag(id: 't-8', uid: '04AABBCC', active: true),
      ]);
      expect(updated.nfcTags.map((t) => t.uid), ['04B1C2D3', '04AABBCC']);
      expect(updated.user.nfcTagCount, 2);
      expect(updated.hasFace, isTrue);
      expect(d.nfcTags, hasLength(1)); // o original não muda
      expect(d.withTags([]).user.nfcTagCount, 0);
    });

    test('withUser troca os dados mantendo tags e rosto', () {
      final d = UserDetail.fromJson(detailJson(tags: [tagJson()], hasFace: true));
      final updated = d.withUser(UserSummary.fromJson(userJson(active: false)));
      expect(updated.user.active, isFalse);
      expect(updated.nfcTags, hasLength(1));
      expect(updated.user.nfcTagCount, 1);
      expect(updated.user.hasFace, isTrue);
    });
  });

  group('UsersPage.fromJson', () {
    test('lê a página e sabe se há mais', () {
      final p = UsersPage.fromJson(pageJson([userJson(), userJson(id: 'u-2')], total: 45, totalPages: 3));
      expect(p.items, hasLength(2));
      expect(p.total, 45);
      expect(p.page, 1);
      expect(p.hasMore, isTrue);
      expect(UsersPage.fromJson(pageJson([], page: 3, totalPages: 3)).hasMore, isFalse);
    });

    test('corpo fora do contrato é rejeitado', () {
      expect(() => UsersPage.fromJson({'page': 1}), throwsFormatException);
      expect(() => UsersPage.fromJson({...pageJson([]), 'data': 'x'}), throwsFormatException);
      expect(() => UsersPage.fromJson({...pageJson([]), 'total': null}), throwsFormatException);
    });
  });

  group('NewUser.toJson', () {
    test('normaliza e-mail e omite opcionais em branco', () {
      const u = NewUser(
        name: '  Ana Souza ',
        email: ' ANA@Teste.com ',
        password: ' s3nha ',
        role: UserRole.visitor,
        document: '   ',
        phone: '',
      );
      expect(u.toJson(), {
        'name': 'Ana Souza',
        'email': 'ana@teste.com',
        'password': ' s3nha ', // a senha nunca é alterada
        'role': 'VISITOR',
      });
    });

    test('envia documento e telefone quando preenchidos', () {
      const u = NewUser(
        name: 'Ana',
        email: 'a@b.com',
        password: '123456',
        role: UserRole.admin,
        document: ' 123 ',
        phone: '11999',
      );
      expect(u.toJson()['document'], '123');
      expect(u.toJson()['phone'], '11999');
      expect(u.toJson()['role'], 'ADMIN');
    });
  });
}
