import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/auth/data/auth_repository.dart';
import 'package:mobile_registry/features/auth/data/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/memory_secure_store.dart';
import '../../helpers/test_app.dart';

Map<String, Object> error(String code, String message) => {
      'error': {'code': code, 'message': message},
    };

Future<ApiException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('O login deveria ter falhado');
}

void main() {
  late MemorySecureStore store;

  setUp(() => store = MemorySecureStore());

  Future<AuthRepository> repoWith(
    List<FakeHandler> script, {
    FakeAdapter? adapter,
  }) async {
    final container = await buildContainer(
      adapter: adapter ?? FakeAdapter(script),
      secureStore: store,
    );
    return container.read(authRepositoryProvider);
  }

  group('sucesso', () {
    test('envia e-mail normalizado e guarda token e perfil com segurança', () async {
      final adapter = FakeAdapter([loginOk()]);
      final repo = await repoWith([], adapter: adapter);

      final user = await repo.login(email: '  Admin@Teste.COM ', password: ' s3nha ');

      expect(user, testAdmin);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://10.0.2.2:3000/api/auth/login');
      expect(request.data, {'email': 'admin@teste.com', 'password': ' s3nha '});
      expect(store.data['auth.token'], 'tok-123');
      expect(jsonDecode(store.data[SessionStorage.userKey]!), testAdmin.toJson());
    });

    test('token e perfil NÃO vão para shared_preferences', () async {
      final repo = await repoWith([loginOk()]);
      await repo.login(email: 'admin@teste.com', password: 'x');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('não envia token antigo no login', () async {
      store.data['auth.token'] = 'antigo';
      final adapter = FakeAdapter([loginOk()]);
      final repo = await repoWith([], adapter: adapter);
      await repo.login(email: 'admin@teste.com', password: 'x');
      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('depois do login, as demais chamadas levam o token', () async {
      final adapter = FakeAdapter([loginOk(), FakeAdapter.json(200, {})]);
      final container = await buildContainer(adapter: adapter, secureStore: store);
      await container
          .read(authRepositoryProvider)
          .login(email: 'admin@teste.com', password: 'x');
      await container.read(dioProvider).get<dynamic>('/users');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer tok-123');
    });
  });

  group('restrição a administradores', () {
    for (final role in ['RESIDENT', 'VISITOR']) {
      test('$role é recusado e nada é guardado', () async {
        final repo = await repoWith([loginOk(role: role)]);
        final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
        expect(e.kind, ApiErrorKind.forbidden);
        expect(e.message, AuthRepository.accessDeniedMessage);
        expect(store.data, isEmpty);
      });
    }

    test('403 do servidor também vira "acesso negado"', () async {
      final repo = await repoWith([
        FakeAdapter.json(403, error('FORBIDDEN', 'Proibido')),
      ]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.message, AuthRepository.accessDeniedMessage);
    });
  });

  group('falhas', () {
    test('401: "e-mail ou senha incorretos" e sem evento de sessão expirada', () async {
      final container = await buildContainer(
        adapter: FakeAdapter([
          FakeAdapter.json(401, error('INVALID_CREDENTIALS', 'x')),
        ]),
        secureStore: store,
      );
      final e = await failureOf(
        container.read(authRepositoryProvider).login(email: 'a@b.com', password: 'x'),
      );
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.message, AuthRepository.wrongCredentialsMessage);
      expect(container.read(sessionExpiredProvider), 0);
      expect(store.data, isEmpty);
    });

    test('404: servidor sem serviço de login', () async {
      final repo = await repoWith([FakeAdapter.json(404, error('NOT_FOUND', 'x'))]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, AuthRepository.loginNotFoundMessage);
    });

    test('400: confira os dados', () async {
      final repo = await repoWith([
        FakeAdapter.json(400, error('VALIDATION_ERROR', 'Dados inválidos')),
      ]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, AuthRepository.invalidDataMessage);
    });

    test('500: mensagem do servidor com problemas, sem repetir o POST', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(500, error('INTERNAL_ERROR', 'stack trace')),
      ]);
      final repo = await repoWith([], adapter: adapter);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.message, ApiException.serverMessage);
      expect(adapter.calls, 1);
    });

    test('sem conexão: mensagem de rede (após novas tentativas)', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]);
      final repo = await repoWith([], adapter: adapter);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.network);
      expect(e.message, ApiException.networkMessage);
      expect(adapter.calls, 4);
    });

    test('timeout de resposta não repete o POST do login', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.receiveTimeout)]);
      final repo = await repoWith([], adapter: adapter);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.timeout);
      expect(adapter.calls, 1);
    });
  });

  group('resposta inesperada', () {
    final bodies = <String, Object>{
      'objeto vazio': <String, Object>{},
      'sem token': {
        'user': {'id': '1', 'name': 'A', 'email': 'a@b.com', 'role': 'ADMIN'},
      },
      'token vazio': {
        'accessToken': '',
        'user': {'id': '1', 'name': 'A', 'email': 'a@b.com', 'role': 'ADMIN'},
      },
      'usuário incompleto': {
        'accessToken': 'x',
        'user': {'id': '1'},
      },
      'usuário não é objeto': {'accessToken': 'x', 'user': 'ana'},
      'lista': <Object>[],
    };

    bodies.forEach((name, body) {
      test(name, () async {
        final repo = await repoWith([FakeAdapter.json(200, body)]);
        final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
        expect(e.message, AuthRepository.unexpectedResponseMessage);
        expect(store.data, isEmpty);
      });
    });
  });

  test('falha ao gravar no armazenamento seguro não deixa sessão pela metade', () async {
    store.failOnWrite = true;
    final repo = await repoWith([loginOk()]);
    final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
    expect(e.message, AuthRepository.storageFailureMessage);
    expect(store.data, isEmpty);
  });
}
