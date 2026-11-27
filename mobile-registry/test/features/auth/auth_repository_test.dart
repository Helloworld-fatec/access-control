import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/auth/data/auth_repository.dart';

import '../../helpers/fake_adapter.dart';
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
  AuthRepository repoWith(List<FakeHandler> script, {FakeAdapter? adapter}) =>
      AuthRepository(testSession(adapter: adapter ?? FakeAdapter(script)).dio);

  group('sucesso', () {
    test('envia e-mail normalizado e retorna token e perfil', () async {
      final adapter = FakeAdapter([loginOk()]);
      final repo = repoWith([], adapter: adapter);

      final (user, token) =
          await repo.login(email: '  Admin@Teste.COM ', password: ' s3nha ');

      expect(user, testAdmin);
      expect(token, 'tok-123');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'http://10.0.2.2:3333/api/login');
      expect(request.data, {'email': 'admin@teste.com', 'password': ' s3nha '});
    });

    test('não envia token antigo no login', () async {
      final adapter = FakeAdapter([loginOk()]);
      final session = testSession(adapter: adapter, signedInAs: testAdmin);
      await AuthRepository(session.dio)
          .login(email: 'admin@teste.com', password: 'x');
      expect(adapter.requests.single.headers.containsKey('Authorization'),
          isFalse);
    });

    test('depois do login, as demais chamadas levam o token', () async {
      final adapter = FakeAdapter([loginOk(), FakeAdapter.json(200, {})]);
      final session = testSession(adapter: adapter);
      await session.submit(email: 'admin@teste.com', password: 'x');
      await session.dio.get<dynamic>('/users');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer tok-123');
    });
  });

  group('restrição a administradores', () {
    for (final role in ['RESIDENT', 'VISITOR']) {
      test('$role é recusado e nada é guardado', () async {
        final repo = repoWith([loginOk(role: role)]);
        final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
        expect(e.kind, ApiErrorKind.forbidden);
        expect(e.message, AuthRepository.accessDeniedMessage);
      });
    }

    test('403 do servidor também vira "acesso negado"', () async {
      final repo = repoWith([
        FakeAdapter.json(403, error('FORBIDDEN', 'Proibido')),
      ]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.message, AuthRepository.accessDeniedMessage);
    });
  });

  group('falhas', () {
    test('401 de login preserva a sessão existente',
        () async {
      final container = testSession(
        signedInAs: testAdmin,
        adapter: FakeAdapter([
          FakeAdapter.json(401, error('INVALID_CREDENTIALS', 'x')),
        ]),
      );
      final e = await failureOf(
        AuthRepository(container.dio).login(email: 'a@b.com', password: 'x'),
      );
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.message, AuthRepository.wrongCredentialsMessage);
      expect(container.user, testAdmin);
      expect(container.endReason, isNull);
    });

    test('404: servidor sem serviço de login', () async {
      final repo = repoWith([FakeAdapter.json(404, error('NOT_FOUND', 'x'))]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, AuthRepository.loginNotFoundMessage);
    });

    test('400: confira os dados', () async {
      final repo = repoWith([
        FakeAdapter.json(400, error('VALIDATION_ERROR', 'Dados inválidos')),
      ]);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, AuthRepository.invalidDataMessage);
    });

    test('500: mensagem do servidor com problemas, sem repetir o POST',
        () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(500, error('INTERNAL_ERROR', 'stack trace')),
      ]);
      final repo = repoWith([], adapter: adapter);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.message, ApiException.serverMessage);
      expect(adapter.calls, 1);
    });

    test('sem conexão: mensagem de rede (após novas tentativas)', () async {
      final adapter =
          FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]);
      final repo = repoWith([], adapter: adapter);
      final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
      expect(e.kind, ApiErrorKind.network);
      expect(e.message, ApiException.networkMessage);
      expect(adapter.calls, 4);
    });

    test('timeout de resposta não repete o POST do login', () async {
      final adapter =
          FakeAdapter([FakeAdapter.fail(DioExceptionType.receiveTimeout)]);
      final repo = repoWith([], adapter: adapter);
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
        final repo = repoWith([FakeAdapter.json(200, body)]);
        final e = await failureOf(repo.login(email: 'a@b.com', password: 'x'));
        expect(e.message, AuthRepository.unexpectedResponseMessage);
      });
    });
  });
}
