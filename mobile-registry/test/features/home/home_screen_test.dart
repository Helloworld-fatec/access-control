import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';
import 'package:mobile_registry/features/users/presentation/new_user_wizard_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Future<TestEnv> startHome(WidgetTester tester) async {
  final env = await buildTestEnv(
    tester,
    signedInAs: testAdmin,
    adapter: RoutedAdapter({'GET /users': usersPage([userJson()])}),
    logicalSize: tallScreen,
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('a área logada é a lista de usuários, com busca e filtros', (tester) async {
    await startHome(tester);

    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Buscar por nome ou documento'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Novo usuário'), findsOneWidget);
  });

  testWidgets('o ícone de configurações abre as configurações, também depois do login',
      (tester) async {
    await startHome(tester);

    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Configurações'), findsOneWidget);
  });

  testWidgets('o botão "Novo usuário" abre o assistente de cadastro', (tester) async {
    await startHome(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo usuário'));
    await tester.pumpAndSettle();

    expect(find.byType(NewUserWizardScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Novo usuário'), findsOneWidget);
    expect(find.text('Etapa 1 de 4'), findsOneWidget);
  });

  group('acessibilidade (US-21)', () {
    testWidgets('ações da barra têm rótulo e área de toque ampla', (tester) async {
      final handle = tester.ensureSemantics();
      await startHome(tester);

      for (final tooltip in ['Configurações', 'Sair']) {
        final finder = find.byTooltip(tooltip);
        expect(finder, findsOneWidget, reason: tooltip);
        final size = tester.getSize(find.ancestor(of: find.byIcon(
          tooltip == 'Sair' ? Icons.logout : Icons.settings,
        ), matching: find.byType(IconButton)));
        expect(size.height, greaterThanOrEqualTo(48), reason: tooltip);
        expect(size.width, greaterThanOrEqualTo(48), reason: tooltip);
      }
      expect(find.bySemanticsLabel('Novo usuário'), findsWidgets);
      handle.dispose();
    });

    testWidgets('respeita o tamanho de texto do sistema sem estourar o layout',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final env = await buildTestEnv(tester, home: const SettingsScreen());
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('botão fica bloqueado com indicador enquanto carrega', (tester) async {
      final gate = Completer<ResponseBody>();
      final env = await buildTestEnv(
        tester,
        home: const SettingsScreen(),
        adapter: FakeAdapter([(options) => gate.future]),
      );
      await tester.pumpWidget(env.widget);

      await tester.ensureVisible(find.text('Salvar e testar conexão'));
      await tester.tap(find.text('Salvar e testar conexão'));
      for (var i = 0;
          i < 20 && find.byType(CircularProgressIndicator).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar'));
      expect(save.onPressed, isNull);

      gate.complete(ResponseBody.fromString(
        '{"status":"ok"}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
