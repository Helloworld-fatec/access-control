import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/core/router/app_router.dart';
import 'package:mobile_registry/features/auth/presentation/login_screen.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/memory_secure_store.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Finder logoutButton() => find.byTooltip('Sair');
Finder confirmButton() => find.widgetWithText(FilledButton, 'Sair');

FakeHandler unauthorized() => apiError(401, 'UNAUTHORIZED', 'Token inválido ou expirado');

/// API falsa: lista de usuários e login (que devolve um token novo).
RoutedAdapter api() => RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'POST /auth/login': loginOk(token: 'tok-novo'),
    });

/// Dispara uma chamada autenticada que o servidor vai recusar com 401.
Future<void> provoke401(WidgetTester tester, RoutedAdapter adapter) async {
  adapter.routes['GET /users'] = unauthorized();
  unawaited(
    containerOf(tester)
        .read(dioProvider)
        .get<dynamic>('/users')
        .then<void>((_) {}, onError: (_) {}),
  );
  await tester.pumpAndSettle();
}

Future<(TestEnv, RoutedAdapter)> startLoggedIn(WidgetTester tester) async {
  final store = MemorySecureStore();
  seedSession(store);
  final adapter = api();
  final env = await buildTestEnv(
    tester,
    secureStore: store,
    signedInAs: testAdmin,
    adapter: adapter,
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  return (env, adapter);
}

Future<void> logInAgain(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'admin@teste.com');
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'senha123');
  await tapVisible(tester, find.widgetWithText(FilledButton, 'Entrar'));
}

void main() {
  group('botão Sair', () {
    testWidgets('a tela inicial tem o ícone Sair na barra superior', (tester) async {
      await startLoggedIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(logoutButton(), findsOneWidget);
    });

    testWidgets('pede confirmação e "Cancelar" mantém a sessão', (tester) async {
      final (env, _) = await startLoggedIn(tester);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      expect(find.text('Sair do aplicativo?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Sair do aplicativo?'), findsNothing);
      expect(env.secureStore.data['auth.token'], 'tok-123');
    });

    testWidgets('confirmar volta ao login e apaga o armazenamento seguro', (tester) async {
      final (env, _) = await startLoggedIn(tester);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(env.secureStore.data, isEmpty);
      // Saída voluntária: sem aviso de "sessão terminou".
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
    });

    testWidgets('depois de sair, as telas protegidas não voltam nem pelo roteador', (tester) async {
      await startLoggedIn(tester);
      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      final router = containerOf(tester).read(appRouterProvider);
      expect(router.canPop(), isFalse);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a lista do administrador anterior não aparece para o próximo login', (tester) async {
      final (_, adapter) = await startLoggedIn(tester);
      expect(find.text('Maria Silva'), findsOneWidget);

      await tester.tap(logoutButton());
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      adapter.routes['GET /users'] = usersPage([userJson(id: 'u-7', name: 'Outra Pessoa')]);
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
      expect(env.secureStore.data['auth.token'], 'tok-novo');
    });

    testWidgets('texto em 2x não estoura a tela inicial nem o diálogo de sair', (tester) async {
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
    testWidgets('401 leva ao login, avisa o motivo e limpa o armazenamento', (tester) async {
      final (env, adapter) = await startLoggedIn(tester);

      await provoke401(tester, adapter);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);
      expect(env.secureStore.data, isEmpty);
    });

    testWidgets('o aviso some depois de um novo login', (tester) async {
      final (env, adapter) = await startLoggedIn(tester);
      await provoke401(tester, adapter);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);

      adapter.routes['GET /users'] = usersPage([userJson()]);
      await logInAgain(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
      expect(env.secureStore.data['auth.token'], 'tok-novo');
    });

    testWidgets('a própria lista, ao receber 401, encerra a sessão', (tester) async {
      final store = MemorySecureStore();
      seedSession(store);
      final adapter = RoutedAdapter({'GET /users': unauthorized()});
      final env = await buildTestEnv(
        tester,
        secureStore: store,
        signedInAs: testAdmin,
        adapter: adapter,
      );
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsOneWidget);
      expect(store.data, isEmpty);
    });

    testWidgets('com as Configurações abertas, o 401 leva ao login e não deixa voltar',
        (tester) async {
      final (_, adapter) = await startLoggedIn(tester);
      await tester.tap(find.byTooltip('Configurações'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await provoke401(tester, adapter);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      // Não há tela protegida "embaixo" para o botão voltar revelar.
      expect(containerOf(tester).read(appRouterProvider).canPop(), isFalse);
    });

    testWidgets('um erro de senha no login não mostra o aviso de sessão expirada', (tester) async {
      final env = await buildTestEnv(
        tester,
        adapter: RoutedAdapter({
          'POST /auth/login': apiError(401, 'INVALID_CREDENTIALS', 'x'),
        }),
      );
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'admin@teste.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'errada');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Entrar'));

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.text(ApiException.unauthorizedMessage), findsNothing);
    });
  });
}
