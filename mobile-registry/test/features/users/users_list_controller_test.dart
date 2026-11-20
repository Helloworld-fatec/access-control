import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/users/application/users_list_controller.dart';
import 'package:mobile_registry/features/users/data/user_models.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

const usersRoute = 'GET /users';

Future<ProviderContainer> start(RoutedAdapter adapter, {bool signedIn = true}) async {
  final container = await buildContainer(
    adapter: adapter,
    signedInAs: signedIn ? testAdmin : null,
  );
  // Mantém o controlador vivo e dispara a carga inicial.
  final sub = container.listen(usersListProvider, (previous, next) {});
  addTearDown(sub.close);
  await settle();
  return container;
}

UsersListState stateOf(ProviderContainer c) => c.read(usersListProvider);

/// Deixa terminar o que está em andamento. O cliente HTTP passa por vários
/// interceptadores (cada um custa voltas do laço de eventos) e o retry faz
/// até 4 tentativas, então as 20 voltas padrão não bastam.
Future<void> settle() => pumpEventQueue(times: 500);

void main() {
  test('carrega a primeira página ao abrir, já logado', () async {
    final adapter = RoutedAdapter({
      usersRoute: usersPage([userJson(), userJson(id: 'u-2', name: 'Pedro')], total: 2),
    });
    final c = await start(adapter);

    final s = stateOf(c);
    expect(s.items.map((u) => u.name), ['Maria Silva', 'Pedro']);
    expect(s.total, 2);
    expect(s.loading, isFalse);
    expect(s.error, isNull);
    expect(adapter.callsTo(usersRoute), 1);
    expect(adapter.requests.single.uri.queryParameters['pageSize'], '20');
  });

  test('sem sessão, não pede nada ao servidor', () async {
    final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
    final c = await start(adapter, signedIn: false);

    expect(stateOf(c).items, isEmpty);
    expect(adapter.calls, 0);
  });

  group('busca e filtros', () {
    test('busca por texto recarrega do início e envia o termo aparado', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
      final c = await start(adapter);

      await c.read(usersListProvider.notifier).setSearch('  maria ');

      expect(stateOf(c).search, 'maria');
      expect(adapter.requests.last.uri.queryParameters['search'], 'maria');
      expect(adapter.requests.last.uri.queryParameters['page'], '1');
    });

    test('mesma busca não recarrega', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
      final c = await start(adapter);
      await c.read(usersListProvider.notifier).setSearch('ana');
      final before = adapter.callsTo(usersRoute);

      await c.read(usersListProvider.notifier).setSearch(' ana ');

      expect(adapter.callsTo(usersRoute), before);
    });

    test('filtro de perfil e de situação enviam os valores da API', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([])});
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);

      await controller.setRole(UserRole.visitor);
      expect(adapter.requests.last.uri.queryParameters['role'], 'VISITOR');

      await controller.setActive(false);
      final q = adapter.requests.last.uri.queryParameters;
      expect(q['role'], 'VISITOR');
      expect(q['active'], 'false');

      await controller.setActive(true);
      expect(adapter.requests.last.uri.queryParameters['active'], 'true');
    });

    test('voltar para "Todos" remove o filtro', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([])});
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);
      await controller.setRole(UserRole.admin);

      await controller.setRole(null);

      expect(stateOf(c).role, isNull);
      expect(adapter.requests.last.uri.queryParameters.containsKey('role'), isFalse);
    });

    test('clearFilters limpa tudo e recarrega uma vez', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);
      await controller.setSearch('x');
      await controller.setRole(UserRole.admin);
      await controller.setActive(true);
      final before = adapter.callsTo(usersRoute);

      await controller.clearFilters();

      final s = stateOf(c);
      expect(s.hasFilters, isFalse);
      expect(adapter.callsTo(usersRoute), before + 1);
      expect(adapter.requests.last.uri.queryParameters.keys, containsAll(['page', 'pageSize']));
      expect(adapter.requests.last.uri.queryParameters.keys.length, 2);
    });

    test('ao mudar o filtro, a lista antiga some na hora', () async {
      final gate = Completer<ResponseBody>();
      var calls = 0;
      final adapter = RoutedAdapter({
        usersRoute: (o) {
          calls++;
          if (calls == 1) return usersPage([userJson()])(o);
          return gate.future;
        },
      });
      final c = await start(adapter);
      expect(stateOf(c).items, hasLength(1));

      unawaited(c.read(usersListProvider.notifier).setRole(UserRole.admin));

      expect(stateOf(c).items, isEmpty);
      expect(stateOf(c).loading, isTrue);
      gate.complete(ResponseBody.fromString('{"data":[],"page":1,"pageSize":20,"total":0,"totalPages":1}', 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
      await settle();
      expect(stateOf(c).loading, isFalse);
    });

    test('resposta antiga (busca anterior) é descartada', () async {
      final slow = Completer<ResponseBody>();
      final adapter = RoutedAdapter({
        usersRoute: (o) {
          final term = o.uri.queryParameters['search'];
          if (term == 'a') return slow.future; // demora
          if (term == 'ab') return usersPage([userJson(name: 'Resultado AB')])(o);
          return usersPage([])(o);
        },
      });
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);

      unawaited(controller.setSearch('a'));
      await controller.setSearch('ab'); // termina antes
      expect(stateOf(c).items.single.name, 'Resultado AB');

      // A resposta lenta de "a" chega depois e NÃO pode sobrescrever.
      slow.complete(ResponseBody.fromString(
        '{"data":[{"id":"x","name":"Resultado A","email":"x@y.com","role":"ADMIN","active":true}],'
        '"page":1,"pageSize":20,"total":1,"totalPages":1}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));
      await settle();

      expect(stateOf(c).items.single.name, 'Resultado AB');
      expect(stateOf(c).search, 'ab');
    });
  });

  group('paginação', () {
    RoutedAdapter twoPages() => RoutedAdapter({
          usersRoute: (o) {
            final page = o.uri.queryParameters['page'];
            if (page == '2') {
              return usersPage([userJson(id: 'u-3', name: 'Carla')], page: 2, total: 3, totalPages: 2)(o);
            }
            return usersPage(
              [userJson(), userJson(id: 'u-2', name: 'Pedro')],
              total: 3,
              totalPages: 2,
            )(o);
          },
        });

    test('loadMore acrescenta a próxima página', () async {
      final adapter = twoPages();
      final c = await start(adapter);
      expect(stateOf(c).hasMore, isTrue);

      await c.read(usersListProvider.notifier).loadMore();

      final s = stateOf(c);
      expect(s.items.map((u) => u.name), ['Maria Silva', 'Pedro', 'Carla']);
      expect(s.page, 2);
      expect(s.hasMore, isFalse);
      expect(adapter.requests.last.uri.queryParameters['page'], '2');
    });

    test('no fim da lista, loadMore não faz nada', () async {
      final adapter = twoPages();
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);
      await controller.loadMore();
      final before = adapter.callsTo(usersRoute);

      await controller.loadMore();

      expect(adapter.callsTo(usersRoute), before);
    });

    test('não duplica usuários repetidos entre páginas', () async {
      final adapter = RoutedAdapter({
        usersRoute: (o) {
          final page2 = o.uri.queryParameters['page'] == '2';
          return usersPage(
            [userJson(), if (page2) userJson(id: 'u-9', name: 'Zélia')],
            page: page2 ? 2 : 1,
            total: 3,
            totalPages: 2,
          )(o);
        },
      });
      final c = await start(adapter);

      await c.read(usersListProvider.notifier).loadMore();

      expect(stateOf(c).items.map((u) => u.id), ['u-1', 'u-9']);
    });

    test('erro ao carregar mais mantém a lista e permite tentar de novo', () async {
      var fail = true;
      final adapter = RoutedAdapter({
        usersRoute: (o) {
          if (o.uri.queryParameters['page'] == '2') {
            if (fail) return FakeAdapter.fail(DioExceptionType.connectionError)(o);
            return usersPage([userJson(id: 'u-3', name: 'Carla')], page: 2, total: 3, totalPages: 2)(o);
          }
          return usersPage([userJson()], total: 3, totalPages: 2)(o);
        },
      });
      final c = await start(adapter);
      final controller = c.read(usersListProvider.notifier);

      await controller.loadMore();
      expect(stateOf(c).items, hasLength(1));
      expect(stateOf(c).moreError, ApiException.networkMessage);
      expect(stateOf(c).loadingMore, isFalse);

      fail = false;
      await controller.loadMore();
      expect(stateOf(c).items, hasLength(2));
      expect(stateOf(c).moreError, isNull);
    });
  });

  group('erros', () {
    test('falha na primeira página mostra a mensagem e permite tentar de novo', () async {
      var fail = true;
      final adapter = RoutedAdapter({
        usersRoute: (o) => fail
            ? FakeAdapter.fail(DioExceptionType.connectionError)(o)
            : usersPage([userJson()])(o),
      });
      final c = await start(adapter);

      expect(stateOf(c).error, ApiException.networkMessage);
      expect(stateOf(c).items, isEmpty);
      expect(stateOf(c).loading, isFalse);

      fail = false;
      await c.read(usersListProvider.notifier).load();

      expect(stateOf(c).error, isNull);
      expect(stateOf(c).items, hasLength(1));
    });

    test('erro do servidor (500) não vaza texto técnico', () async {
      final adapter = RoutedAdapter({usersRoute: apiError(500, 'INTERNAL_ERROR', 'stack trace')});
      final c = await start(adapter);
      expect(stateOf(c).error, ApiException.serverMessage);
    });

    test('lista vazia não é erro', () async {
      final adapter = RoutedAdapter({usersRoute: usersPage([])});
      final c = await start(adapter);
      expect(stateOf(c).items, isEmpty);
      expect(stateOf(c).error, isNull);
      expect(stateOf(c).total, 0);
    });
  });

  test('refresh mantém os filtros', () async {
    final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
    final c = await start(adapter);
    final controller = c.read(usersListProvider.notifier);
    await controller.setRole(UserRole.resident);

    await controller.refresh();

    expect(adapter.requests.last.uri.queryParameters['role'], 'RESIDENT');
  });

  test('ao sair, a lista é esvaziada (nunca mostra dados de outra sessão)', () async {
    final adapter = RoutedAdapter({usersRoute: usersPage([userJson()])});
    final c = await start(adapter);
    expect(stateOf(c).items, hasLength(1));

    await c.read(authProvider.notifier).signOut();
    await settle();

    expect(stateOf(c).items, isEmpty);
    expect(stateOf(c).hasFilters, isFalse);
    expect(adapter.callsTo(usersRoute), 1); // não recarregou sem sessão
  });
}
