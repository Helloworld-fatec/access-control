import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/auth/presentation/login_screen.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/features/users/presentation/user_form_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Finder logoutButton() => find.byTooltip('Sair');
Finder confirmButton() => find.widgetWithText(FilledButton, 'Sair');

FakeHandler unauthorized() =>
    apiError(401, 'UNAUTHORIZED', 'Token inválido ou expirado');

/// API falsa: lista de usuários e login (que devolve um token novo).
RoutedAdapter api() => RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'POST /login': loginOk(token: 'tok-novo'),
    });

/// Dispara uma chamada autenticada que o servidor vai recusar com 401.
Future<void> provoke401(
    WidgetTester tester, TestEnv env, RoutedAdapter adapter) async {
  adapter.routes['GET /users'] = unauthorized();
  unawaited(
    env.session.dio.get<dynamic>('/users').then<void>((_) {}, onError: (_) {}),
  );
  await tester.pumpAndSettle();
}

Future<(TestEnv, RoutedAdapter)> startLoggedIn(WidgetTester tester) async {
  final adapter = api();
  final env = await buildTestEnv(
    tester,
    signedInAs: testAdmin,
    adapter: adapter,
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  return (env, adapter);
}

Future<void> logInAgain(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'), 'admin@teste.com');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'), 'senha123');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Entrar'));
}

void main() {
  group('botão Sair', () {
    testWidgets('a tela inicial tem o ícone Sair na barra superior',
        (tester) async {
      await startLoggedIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(logoutButton(), findsOneWidget);
    });

    testWidgets('pede confirmação e "Cancelar" mantém a sessão',
        (tester) async {
      final (env, _) = await startLoggedIn(tester);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      expect(find.text('Sair do aplicativo?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Sair do aplicativo?'), findsNothing);
      expect(env.session.isAuthenticated, isTrue);
    });

    testWidgets('confirmar volta ao login e limpa a sessão', (tester) async {
      final (env, _) = await startLoggedIn(tester);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(env.session.isAuthenticated, isFalse);
      // Saída voluntária: sem aviso de "sessão terminou".
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
    });

    testWidgets(
        'depois de sair, as telas protegidas não voltam pelo botão voltar',
        (tester) async {
      await startLoggedIn(tester);
      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets(
        'a lista do administrador anterior não aparece para o próximo login',
        (tester) async {
      final (_, adapter) = await startLoggedIn(tester);
      expect(find.text('Maria Silva'), findsOneWidget);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      adapter.routes['GET /users'] =
          usersPage([userJson(id: 'u-7', name: 'Outra Pessoa')]);
      await logInAgain(tester);

      expect(find.text('Maria Silva'), findsNothing);
      expect(find.text('Outra Pessoa'), findsOneWidget);
    });

    testWidgets('dá para entrar de novo depois de sair', (tester) async {
      final (env, _) = await startLoggedIn(tester);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      await logInAgain(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(env.session.isAuthenticated, isTrue);
    });

    testWidgets('texto em 2x não estoura a tela inicial nem o diálogo de sair',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await startLoggedIn(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sair do aplicativo?'), findsOneWidget);
    });
  });

  group('sessão expirada', () {
    testWidgets('401 leva ao login, avisa o motivo e limpa a sessão',
        (tester) async {
      final (env, adapter) = await startLoggedIn(tester);

      await provoke401(tester, env, adapter);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);
      expect(env.session.isAuthenticated, isFalse);
    });

    testWidgets('o aviso some depois de um novo login', (tester) async {
      final (env, adapter) = await startLoggedIn(tester);
      await provoke401(tester, env, adapter);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);

      adapter.routes['GET /users'] = usersPage([userJson()]);
      await logInAgain(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
      expect(env.session.isAuthenticated, isTrue);
    });

    testWidgets('a própria lista, ao receber 401, encerra a sessão',
        (tester) async {
      final adapter = RoutedAdapter({'GET /users': unauthorized()});
      final env = await buildTestEnv(
        tester,
        signedInAs: testAdmin,
        adapter: adapter,
      );
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);
      expect(env.session.isAuthenticated, isFalse);
    });

    testWidgets(
        'com o formulário aberto, o 401 leva ao login e não deixa voltar',
        (tester) async {
      final (env, adapter) = await startLoggedIn(tester);
      await tester.tap(find.text('Novo usuário'));
      await tester.pumpAndSettle();
      expect(find.byType(UserFormScreen), findsOneWidget);

      await provoke401(tester, env, adapter);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(UserFormScreen), findsNothing);
      // Não há tela protegida "embaixo" para o botão voltar revelar.
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse);
    });

    testWidgets(
        'um erro de senha no login não mostra o aviso de sessão expirada',
        (tester) async {
      final env = await buildTestEnv(
        tester,
        adapter: RoutedAdapter({
          'POST /login': apiError(401, 'INVALID_CREDENTIALS', 'x'),
        }),
      );
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'E-mail'), 'admin@teste.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Senha'), 'errada');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Entrar'));

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
    });
  });
}
