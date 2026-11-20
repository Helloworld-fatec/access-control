import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/auth/data/session_storage.dart';
import 'package:mobile_registry/features/settings/data/connection_repository.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/memory_secure_store.dart';
import '../../helpers/test_app.dart';

FakeHandler unauthorized() => FakeAdapter.json(401, {
      'error': {'code': 'UNAUTHORIZED', 'message': 'Token inválido ou expirado'},
    });

/// Container já logado, com a sessão guardada no armazenamento seguro.
Future<ProviderContainer> signedIn({
  FakeAdapter? adapter,
  required MemorySecureStore store,
}) async {
  seedSession(store);
  final container = await buildContainer(
    adapter: adapter,
    secureStore: store,
    signedInAs: testAdmin,
  );
  // Ativa o tratamento global de sessão (no app, o roteador faz isso).
  container.read(authProvider);
  return container;
}

void main() {
  late MemorySecureStore store;

  setUp(() => store = MemorySecureStore());

  group('Sair (logout)', () {
    test('apaga token e perfil e volta a "ninguém logado"', () async {
      final container = await signedIn(store: store);
      expect(store.data, isNotEmpty);

      await container.read(authProvider.notifier).signOut();

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.endReason, SessionEndReason.signedOut);
      expect(store.data, isEmpty);
    });

    test('mesmo que o aparelho falhe ao apagar, o usuário sai e o resto é apagado', () async {
      final container = await signedIn(store: store);
      store.failDeleteFor.add('auth.token');

      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(store.data.containsKey(SessionStorage.userKey), isFalse);
    });

    test('sem sessão, não faz nada', () async {
      final container = await buildContainer(secureStore: store);
      await container.read(authProvider.notifier).signOut();
      expect(container.read(authProvider).endReason, isNull);
    });

    test('uma nova sessão depois de sair não guarda o motivo anterior', () async {
      final container = await signedIn(store: store);
      await container.read(authProvider.notifier).signOut();

      container.read(authProvider.notifier).signedIn(testAdmin);

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.endReason, isNull);
    });
  });

  group('sessão expirada (401)', () {
    test('um 401 em chamada autenticada encerra a sessão e limpa o armazenamento', () async {
      final container = await signedIn(
        adapter: FakeAdapter([unauthorized()]),
        store: store,
      );

      await expectLater(
        container.read(dioProvider).get<dynamic>('/users'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue(times: 200);

      final auth = container.read(authProvider);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.endReason, SessionEndReason.expired);
      expect(store.data, isEmpty);
    });

    test('o 401 vale para qualquer tipo de chamada (POST também)', () async {
      final container = await signedIn(
        adapter: FakeAdapter([unauthorized()]),
        store: store,
      );

      await expectLater(
        container.read(dioProvider).post<dynamic>('/users', data: {'name': 'Ana'}),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).endReason, SessionEndReason.expired);
    });

    test('o token que o servidor recusou é o que o app enviou', () async {
      final adapter = FakeAdapter([unauthorized()]);
      final container = await signedIn(adapter: adapter, store: store);

      await expectLater(
        container.read(dioProvider).get<dynamic>('/users'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-123');
      expect(container.read(sessionExpiredProvider.notifier).lastSentToken, 'tok-123');
      // O encerramento da sessão roda em segundo plano: deixa terminar antes
      // de o container ser descartado.
      await pumpEventQueue(times: 200);
    });

    test('401 atrasado de uma sessão anterior não derruba a sessão atual', () async {
      final container = await signedIn(store: store);

      // O servidor recusou um token ANTIGO; a sessão atual usa tok-123.
      container.read(sessionExpiredProvider.notifier).notify('token-antigo');
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(store.data['auth.token'], 'tok-123');
    });

    test('401 do token atual encerra a sessão', () async {
      final container = await signedIn(store: store);

      container.read(sessionExpiredProvider.notifier).notify('tok-123');
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).endReason, SessionEndReason.expired);
      expect(store.data, isEmpty);
    });

    test('401 de chamada sem token, estando logado, também encerra', () async {
      final container = await signedIn(store: store);

      container.read(sessionExpiredProvider.notifier).notify();
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).endReason, SessionEndReason.expired);
    });

    test('vários 401 ao mesmo tempo encerram a sessão uma única vez', () async {
      final container = await signedIn(store: store);
      var ended = 0;
      final sub = container.listen(authProvider, (previous, next) {
        if (previous!.isAuthenticated && !next.isAuthenticated) ended++;
      });
      addTearDown(sub.close);

      final events = container.read(sessionExpiredProvider.notifier);
      events.notify('tok-123');
      events.notify('tok-123');
      events.notify('tok-123');
      await pumpEventQueue(times: 200);

      expect(ended, 1);
      expect(container.read(authProvider).endReason, SessionEndReason.expired);
      expect(store.data, isEmpty);
    });

    test('401 depois de sair é ignorado e não troca o motivo', () async {
      final container = await signedIn(store: store);
      await container.read(authProvider.notifier).signOut();

      container.read(sessionExpiredProvider.notifier).notify('tok-123');
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).endReason, SessionEndReason.signedOut);
    });

    test('mesmo que o aparelho falhe ao apagar, a sessão expirada encerra', () async {
      final container = await signedIn(store: store);
      store.failDeleteFor.add('auth.token');

      container.read(sessionExpiredProvider.notifier).notify('tok-123');
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(store.data.containsKey(SessionStorage.userKey), isFalse);
    });

    test('depois de expirar, um novo login volta a funcionar', () async {
      final container = await signedIn(store: store);
      container.read(sessionExpiredProvider.notifier).notify('tok-123');
      await pumpEventQueue(times: 200);

      container.read(authProvider.notifier).signedIn(testAdmin);

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).endReason, isNull);
    });

    test('testar a conexão nunca encerra a sessão, mesmo com 401', () async {
      final container = await signedIn(
        adapter: FakeAdapter([unauthorized()]),
        store: store,
      );

      await expectLater(
        container.read(connectionRepositoryProvider).check(),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue(times: 200);

      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(sessionExpiredProvider), 0);
      expect(store.data, isNotEmpty);
    });
  });
}
