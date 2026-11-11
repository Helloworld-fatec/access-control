import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/auth/data/auth_repository.dart';
import 'package:mobile_registry/features/auth/presentation/login_screen.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder enterButton() => find.widgetWithText(FilledButton, 'Entrar');

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'admin@teste.com',
  String password = 'senha123',
}) async {
  await tester.enterText(field('E-mail'), email);
  await tester.enterText(field('Senha'), password);
  await tapVisible(tester, enterButton());
}

Map<String, Object> error(String code, String message) => {
      'error': {'code': code, 'message': message},
    };

void main() {
  testWidgets('mostra e-mail, senha, "Mostrar senha" e o servidor configurado',
      (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(field('E-mail'), findsOneWidget);
    expect(field('Senha'), findsOneWidget);
    expect(find.text('Mostrar senha'), findsOneWidget);
    expect(enterButton(), findsOneWidget);
    expect(find.text('http://10.0.2.2:3000/api'), findsOneWidget);
  });

  testWidgets('campos vazios mostram as mensagens e nada é enviado', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await tapVisible(tester, enterButton());

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(env.adapter.calls, 0);
  });

  testWidgets('e-mail inválido mostra mensagem clara', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, email: 'admin');

    expect(find.text('E-mail inválido. Exemplo: nome@exemplo.com.'), findsOneWidget);
    expect(env.adapter.calls, 0);
  });

  testWidgets('"Mostrar senha" alterna a visibilidade', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    bool obscured() => tester
        .widget<TextField>(
          find.descendant(of: field('Senha'), matching: find.byType(TextField)),
        )
        .obscureText;

    expect(obscured(), isTrue);
    await tapVisible(tester, find.text('Mostrar senha'));
    expect(obscured(), isFalse);
    await tapVisible(tester, find.text('Mostrar senha'));
    expect(obscured(), isTrue);
  });

  testWidgets('login de administrador entra na área logada e guarda a sessão',
      (tester) async {
    final env = await buildTestEnv(tester, adapter: FakeAdapter([loginOk()]));
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Usuários'), findsOneWidget); // título da lista
    expect(env.secureStore.data['auth.token'], 'tok-123');
    expect(env.prefs.getKeys().where((k) => k.startsWith('auth')), isEmpty);
  });

  testWidgets('senha errada mostra a mensagem e permanece no login', (tester) async {
    final env = await buildTestEnv(
      tester,
      adapter: FakeAdapter([
        FakeAdapter.json(401, error('INVALID_CREDENTIALS', 'x')),
      ]),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);

    expect(find.text(AuthRepository.wrongCredentialsMessage), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('admin@teste.com'), findsOneWidget); // e-mail preservado
    expect(env.secureStore.data, isEmpty);
  });

  testWidgets('perfil que não é administrador recebe "acesso negado"', (tester) async {
    final env = await buildTestEnv(
      tester,
      adapter: FakeAdapter([loginOk(role: 'RESIDENT')]),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, email: 'morador@teste.com');

    expect(find.text(AuthRepository.accessDeniedMessage), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(env.secureStore.data, isEmpty);
  });

  testWidgets('servidor sem login (404) orienta a conferir a configuração',
      (tester) async {
    final env = await buildTestEnv(
      tester,
      adapter: FakeAdapter([
        FakeAdapter.json(404, error('NOT_FOUND', 'Rota não encontrada')),
      ]),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);

    expect(find.text(AuthRepository.loginNotFoundMessage), findsOneWidget);
  });

  testWidgets('servidor fora do ar mostra mensagem em linguagem simples',
      (tester) async {
    final env = await buildTestEnv(
      tester,
      adapter: FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);

    expect(find.text(ApiException.networkMessage), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('durante o envio mostra carregamento e bloqueia o botão', (tester) async {
    final gate = Completer<ResponseBody>();
    // Rotas por caminho: o corpo do login só pode ser consumido uma vez, e
    // depois do login a lista de usuários faz a própria chamada.
    final env = await buildTestEnv(
      tester,
      adapter: RoutedAdapter({
        'POST /auth/login': (options) => gate.future,
        'GET /users': usersPage([]),
      }),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await tester.enterText(field('E-mail'), 'admin@teste.com');
    await tester.enterText(field('Senha'), 'senha123');
    await tester.pumpAndSettle();
    await tester.ensureVisible(enterButton());
    await tester.pumpAndSettle();
    await tester.tap(enterButton());
    for (var i = 0;
        i < 20 && find.byType(CircularProgressIndicator).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(enterButton()).onPressed, isNull);
    expect(env.adapter.calls, 1);

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
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    // Só um POST de login (a lista de usuários faz um GET depois de entrar).
    expect(env.adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets('a configuração do servidor é acessível antes do login', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Configurar servidor'));
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Voltar leva de volta ao login.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('com sessão guardada, o app abre direto na área logada', (tester) async {
    final env = await buildTestEnv(tester, signedInAs: testAdmin);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('texto em 2x não estoura o layout do login', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final env = await buildTestEnv(tester, home: const LoginScreen());
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(enterButton(), findsOneWidget);
  });

  testWidgets('elementos do login têm rótulos para leitores de tela', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Entrar'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('E-mail')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Senha')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Mostrar senha')), findsWidgets);
    handle.dispose();
  });
}
