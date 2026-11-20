import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/router/app_router.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/auth/presentation/login_screen.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';

import '../../helpers/test_app.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  testWidgets('sem sessão, qualquer tela protegida leva ao login', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('endereço desconhecido sem sessão também leva ao login', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    containerOf(tester).read(appRouterProvider).go('/qualquer-coisa');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('configurações abrem mesmo sem sessão', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    containerOf(tester).read(appRouterProvider).go(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('com sessão, a tela de login não é acessível', (tester) async {
    final env = await buildTestEnv(tester, signedInAs: testAdmin);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('ao autenticar, o app sai do login sozinho', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    containerOf(tester).read(authProvider.notifier).signedIn(testAdmin);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
