import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/features/users/data/user_models.dart';
import 'package:mobile_registry/features/users/data/users_repository.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Future<ApiException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('Deveria ter falhado');
}

void main() {
  Future<(UsersRepository, FakeAdapter)> setup(List<FakeHandler> script) async {
    final adapter = FakeAdapter(script);
    final container = await buildContainer(adapter: adapter, signedInAs: testAdmin);
    return (container.read(usersRepositoryProvider), adapter);
  }

  group('list', () {
    test('GET /users com paginação e sem filtros vazios', () async {
      final (repo, adapter) = await setup([usersPage([userJson()])]);

      final page = await repo.list();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/users');
      expect(request.uri.queryParameters, {'page': '1', 'pageSize': '20'});
      expect(page.items.single.name, 'Maria Silva');
    });

    test('envia busca (aparada), perfil e situação', () async {
      final (repo, adapter) = await setup([usersPage([])]);

      await repo.list(
        page: 2,
        pageSize: 10,
        search: '  maria  ',
        role: UserRole.admin,
        active: false,
      );

      expect(adapter.requests.single.uri.queryParameters, {
        'page': '2',
        'pageSize': '10',
        'search': 'maria',
        'role': 'ADMIN',
        'active': 'false',
      });
    });

    test('busca em branco não é enviada', () async {
      final (repo, adapter) = await setup([usersPage([])]);
      await repo.list(search: '   ');
      expect(adapter.requests.single.uri.queryParameters.containsKey('search'), isFalse);
    });

    test('resposta fora do contrato vira mensagem simples', () async {
      final (repo, _) = await setup([FakeAdapter.json(200, {'oops': true})]);
      final e = await failureOf(repo.list());
      expect(e.message, UsersRepository.unexpectedResponseMessage);
    });

    test('lista no formato errado (array) também é rejeitada', () async {
      final (repo, _) = await setup([FakeAdapter.json(200, <Object>[])]);
      final e = await failureOf(repo.list());
      expect(e.message, UsersRepository.unexpectedResponseMessage);
    });

    test('erro de rede sai como ApiException de rede', () async {
      final (repo, _) = await setup([FakeAdapter.fail(DioExceptionType.connectionError)]);
      final e = await failureOf(repo.list());
      expect(e.kind, ApiErrorKind.network);
      expect(e.message, ApiException.networkMessage);
    });

    test('500 não vaza texto técnico', () async {
      final (repo, _) = await setup([apiError(500, 'INTERNAL_ERROR', 'stack trace')]);
      final e = await failureOf(repo.list());
      expect(e.message, ApiException.serverMessage);
    });
  });

  group('get', () {
    test('GET /users/{id} devolve o detalhe', () async {
      final (repo, adapter) = await setup([FakeAdapter.json(200, detailJson(tags: [tagJson()]))]);
      final d = await repo.get('u-1');
      expect(adapter.requests.single.uri.path, '/api/users/u-1');
      expect(d.nfcTags, hasLength(1));
    });

    test('404 usa a mensagem do servidor', () async {
      final (repo, _) = await setup([apiError(404, 'USER_NOT_FOUND', 'Usuário não encontrado')]);
      final e = await failureOf(repo.get('x'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, 'Usuário não encontrado');
    });
  });

  group('create', () {
    const newUser = NewUser(
      name: 'Ana Souza',
      email: 'ANA@teste.com',
      password: 'segredo1',
      role: UserRole.resident,
    );

    test('POST /users com o corpo do backend', () async {
      final (repo, adapter) = await setup([FakeAdapter.json(201, userJson(name: 'Ana Souza'))]);

      final created = await repo.create(newUser);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/users');
      expect(request.data, {
        'name': 'Ana Souza',
        'email': 'ana@teste.com',
        'password': 'segredo1',
        'role': 'RESIDENT',
      });
      expect(created.name, 'Ana Souza');
    });

    test('400 expõe os erros por campo', () async {
      final (repo, _) = await setup([
        apiError(400, 'VALIDATION_ERROR', 'Dados inválidos', [
          {'path': 'email', 'message': 'E-mail inválido'},
          {'path': 'password', 'message': 'Senha deve ter ao menos 6 caracteres'},
        ]),
      ]);
      final e = await failureOf(repo.create(newUser));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.fieldErrors, {
        'email': 'E-mail inválido',
        'password': 'Senha deve ter ao menos 6 caracteres',
      });
    });

    test('409 devolve a mensagem de conflito do servidor', () async {
      final (repo, _) = await setup([apiError(409, 'USER_CONFLICT', 'E-mail ou documento já cadastrado')]);
      final e = await failureOf(repo.create(newUser));
      expect(e.kind, ApiErrorKind.conflict);
      expect(e.message, 'E-mail ou documento já cadastrado');
    });

    test('timeout de resposta não repete o POST (evita cadastro duplicado)', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.receiveTimeout)]);
      final container = await buildContainer(adapter: adapter, signedInAs: testAdmin);
      final e = await failureOf(container.read(usersRepositoryProvider).create(newUser));
      expect(e.kind, ApiErrorKind.timeout);
      expect(adapter.calls, 1);
    });
  });

  group('update e setActive', () {
    test('PUT /users/{id} envia só o que mudou', () async {
      final (repo, adapter) = await setup([FakeAdapter.json(200, userJson(name: 'Novo Nome'))]);

      final updated = await repo.update('u-1', {'name': 'Novo Nome'});

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri.path, '/api/users/u-1');
      expect(request.data, {'name': 'Novo Nome'});
      expect(updated.name, 'Novo Nome');
    });

    test('PATCH /users/{id}/status envia {active}', () async {
      final (repo, adapter) = await setup([FakeAdapter.json(200, userJson(active: false))]);

      final updated = await repo.setActive('u-1', active: false);

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.uri.path, '/api/users/u-1/status');
      expect(request.data, {'active': false});
      expect(updated.active, isFalse);
    });
  });

  test('todas as chamadas levam o token do administrador', () async {
    final adapter = FakeAdapter([usersPage([])]);
    final container = await buildContainer(adapter: adapter, signedInAs: testAdmin);
    await container.read(tokenStoreProvider).write('tok-xyz');
    await container.read(usersRepositoryProvider).list();
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-xyz');
  });

  group('tags NFC', () {
    FakeHandler noContent() =>
        (options) async => ResponseBody.fromString('', 204);

    test('addTag: POST /users/{id}/tags com o UID', () async {
      final (repo, adapter) = await setup([FakeAdapter.json(201, tagJson(uid: '04A32F1B'))]);

      final tag = await repo.addTag('u-1', '04A32F1B');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/users/u-1/tags');
      expect(request.data, {'uid': '04A32F1B'});
      expect(tag.uid, '04A32F1B');
    });

    test('addTag: UID repetido (409) mostra mensagem fixa, sem texto do servidor', () async {
      final (repo, _) = await setup([
        apiError(409, 'TAG_CONFLICT', 'Tag já vinculada a Fulano de Tal'),
      ]);
      final e = await failureOf(repo.addTag('u-1', '04A32F1B'));
      expect(e.kind, ApiErrorKind.conflict);
      expect(e.message, UsersRepository.tagConflictMessage);
      expect(e.message, isNot(contains('Fulano')));
    });

    test('addTag: 400 de UID inválido expõe o campo', () async {
      final (repo, _) = await setup([
        apiError(400, 'VALIDATION_ERROR', 'Dados inválidos', [
          {'path': 'uid', 'message': 'UID inválido'},
        ]),
      ]);
      final e = await failureOf(repo.addTag('u-1', 'x'));
      expect(e.fieldErrors, {'uid': 'UID inválido'});
    });

    test('removeTag: DELETE /users/{id}/tags/{tagId} (204 sem corpo)', () async {
      final (repo, adapter) = await setup([noContent()]);

      await repo.removeTag('u-1', 't-1');

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.path, '/api/users/u-1/tags/t-1');
    });

    test('removeTag: tag que já não existe (404) conta como removida', () async {
      final (repo, _) = await setup([apiError(404, 'TAG_NOT_FOUND', 'Tag não encontrada')]);
      await repo.removeTag('u-1', 't-1'); // não lança
    });

    test('removeTag: falha de servidor continua sendo erro', () async {
      final (repo, _) = await setup([apiError(500, 'INTERNAL_ERROR', 'x')]);
      final e = await failureOf(repo.removeTag('u-1', 't-1'));
      expect(e.message, ApiException.serverMessage);
    });

    test('replaceTag: vincula a NOVA primeiro e só depois remove a antiga', () async {
      final (repo, adapter) = await setup([
        FakeAdapter.json(201, tagJson(id: 't-2', uid: '04B1C2D3')),
        noContent(),
      ]);

      final result = await repo.replaceTag(userId: 'u-1', oldTagId: 't-1', newUid: '04B1C2D3');

      expect(adapter.requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(adapter.requests[0].uri.path, '/api/users/u-1/tags');
      expect(adapter.requests[1].uri.path, '/api/users/u-1/tags/t-1');
      expect(result.added.uid, '04B1C2D3');
      expect(result.oldTagRemoved, isTrue);
    });

    test('replaceTag: se a nova der conflito, a antiga NÃO é removida', () async {
      final (repo, adapter) = await setup([apiError(409, 'TAG_CONFLICT', 'x')]);

      final e = await failureOf(
        repo.replaceTag(userId: 'u-1', oldTagId: 't-1', newUid: '04B1C2D3'),
      );

      expect(e.message, UsersRepository.tagConflictMessage);
      expect(adapter.calls, 1); // só o POST; nenhum DELETE
    });

    test('replaceTag: nova vinculada mas remoção falhou é informado, sem perder a nova', () async {
      final (repo, _) = await setup([
        FakeAdapter.json(201, tagJson(id: 't-2', uid: '04B1C2D3')),
        apiError(500, 'INTERNAL_ERROR', 'x'),
      ]);

      final result = await repo.replaceTag(userId: 'u-1', oldTagId: 't-1', newUid: '04B1C2D3');

      expect(result.added.id, 't-2');
      expect(result.oldTagRemoved, isFalse);
      expect(result.removeError!.message, ApiException.serverMessage);
    });
  });
}
