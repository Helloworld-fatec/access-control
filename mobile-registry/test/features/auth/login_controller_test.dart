import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/auth/application/session_controller.dart';
import 'package:mobile_registry/features/auth/data/auth_repository.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';

void main() {
  test('começa sem ninguém logado', () async {
    final container = testSession();
    expect(container.isAuthenticated, isFalse);
  });

  test('expõe o administrador da sessão em memória', () async {
    final container = testSession(signedInAs: testAdmin);
    expect(container.user, testAdmin);
  });

  test('ignora 401 de um token antigo e encerra a sessão para o token atual',
      () {
    final session = testSession(signedInAs: testAdmin);
    session.startSession(testAdmin, 'tok-novo');
    session.expire('tok-123');
    expect(session.user, testAdmin);
    expect(session.endReason, isNull);

    session.expire('tok-novo');
    expect(session.user, isNull);
    expect(session.endReason, SessionEndReason.expired);
  });

  test('limpa o Bearer no logout', () async {
    final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
    final session = testSession(adapter: adapter, signedInAs: testAdmin);
    await session.dio.get<dynamic>('/users');
    session.signOut();
    await session.dio.get<dynamic>('/users');

    expect(adapter.requests.first.headers['Authorization'], 'Bearer tok-123');
    expect(adapter.requests.last.headers.containsKey('Authorization'), isFalse);
    expect(session.endReason, SessionEndReason.signedOut);
  });

  test('login com sucesso autentica o administrador', () async {
    final container = testSession(adapter: FakeAdapter([loginOk()]));

    await container.submit(email: 'admin@teste.com', password: 'x');

    expect(container.user, testAdmin);
    expect(container.error, isNull);
    expect(container.loading, isFalse);
  });

  test('credenciais erradas deixam a mensagem e não autenticam', () async {
    final container = testSession(
      adapter: FakeAdapter([
        FakeAdapter.json(401, {
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'x'},
        }),
      ]),
    );

    await container.submit(email: 'a@b.com', password: 'errada');

    expect(container.isAuthenticated, isFalse);
    expect(
      container.error,
      AuthRepository.wrongCredentialsMessage,
    );
  });

  test('perfil que não é administrador não autentica', () async {
    final container =
        testSession(adapter: FakeAdapter([loginOk(role: 'RESIDENT')]));

    await container.submit(email: 'a@b.com', password: 'x');

    expect(container.isAuthenticated, isFalse);
    expect(
      container.error,
      AuthRepository.accessDeniedMessage,
    );
  });

  test('segundo envio durante o carregamento é ignorado', () async {
    final gate = Completer<ResponseBody>();
    final adapter = FakeAdapter([(options) => gate.future]);
    final container = testSession(adapter: adapter);
    final controller = container;

    final first = controller.submit(email: 'admin@teste.com', password: 'x');
    expect(container.loading, isTrue);
    // Segundo toque enquanto o primeiro ainda está em andamento: é ignorado.
    await controller.submit(email: 'admin@teste.com', password: 'x');

    gate.complete(
      ResponseBody.fromString(
        '{"accessToken":"t","user":{"id":"u1","name":"Ana Souza",'
        '"email":"admin@teste.com","role":"ADMIN"}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await first;
    expect(container.user, testAdmin);
    // Só a primeira chamada chegou ao servidor.
    expect(adapter.calls, 1);
  });

  test('depois de um erro, uma nova tentativa limpa a mensagem', () async {
    final container = testSession(
      adapter: FakeAdapter([
        FakeAdapter.json(401, {
          'error': {'code': 'INVALID_CREDENTIALS', 'message': 'x'},
        }),
        loginOk(),
      ]),
    );
    final controller = container;

    await controller.submit(email: 'admin@teste.com', password: 'errada');
    expect(container.error, isNotNull);

    await controller.submit(email: 'admin@teste.com', password: 'certa');
    expect(container.error, isNull);
    expect(container.isAuthenticated, isTrue);
  });
}
