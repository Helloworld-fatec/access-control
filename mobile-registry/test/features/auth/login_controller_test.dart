import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/auth/data/auth_repository.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';

ProviderContainer keepLoginAlive(ProviderContainer container) {
  // O controlador é autoDispose: um "ouvinte" o mantém vivo durante o teste.
  final sub = container.listen(loginControllerProvider, (previous, next) {});
  addTearDown(sub.close);
  return container;
}

void main() {
  test('começa sem ninguém logado', () async {
    final container = await buildContainer();
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('começa logado quando há sessão restaurada', () async {
    final container = await buildContainer(signedInAs: testAdmin);
    expect(container.read(authProvider).user, testAdmin);
  });

  test('login com sucesso autentica o administrador', () async {
    final container = keepLoginAlive(
      await buildContainer(adapter: FakeAdapter([loginOk()])),
    );

    await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'admin@teste.com', password: 'x');

    expect(container.read(authProvider).user, testAdmin);
    expect(container.read(loginControllerProvider).error, isNull);
    expect(container.read(loginControllerProvider).loading, isFalse);
  });

  test('credenciais erradas deixam a mensagem e não autenticam', () async {
    final container = keepLoginAlive(
      await buildContainer(
        adapter: FakeAdapter([
          FakeAdapter.json(401, {
            'error': {'code': 'INVALID_CREDENTIALS', 'message': 'x'},
          }),
        ]),
      ),
    );

    await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'a@b.com', password: 'errada');

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(
      container.read(loginControllerProvider).error,
      AuthRepository.wrongCredentialsMessage,
    );
  });

  test('perfil que não é administrador não autentica', () async {
    final container = keepLoginAlive(
      await buildContainer(adapter: FakeAdapter([loginOk(role: 'RESIDENT')])),
    );

    await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'a@b.com', password: 'x');

    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(
      container.read(loginControllerProvider).error,
      AuthRepository.accessDeniedMessage,
    );
  });

  test('segundo envio durante o carregamento é ignorado', () async {
    final gate = Completer<ResponseBody>();
    final adapter = FakeAdapter([(options) => gate.future]);
    final container = keepLoginAlive(await buildContainer(adapter: adapter));
    final controller = container.read(loginControllerProvider.notifier);

    final first = controller.submit(email: 'admin@teste.com', password: 'x');
    expect(container.read(loginControllerProvider).loading, isTrue);
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
    expect(container.read(authProvider).user, testAdmin);
    // Só a primeira chamada chegou ao servidor.
    expect(adapter.calls, 1);
  });

  test('depois de um erro, uma nova tentativa limpa a mensagem', () async {
    final container = keepLoginAlive(
      await buildContainer(
        adapter: FakeAdapter([
          FakeAdapter.json(401, {
            'error': {'code': 'INVALID_CREDENTIALS', 'message': 'x'},
          }),
          loginOk(),
        ]),
      ),
    );
    final controller = container.read(loginControllerProvider.notifier);

    await controller.submit(email: 'admin@teste.com', password: 'errada');
    expect(container.read(loginControllerProvider).error, isNotNull);

    await controller.submit(email: 'admin@teste.com', password: 'certa');
    expect(container.read(loginControllerProvider).error, isNull);
    expect(container.read(authProvider).isAuthenticated, isTrue);
  });
}
