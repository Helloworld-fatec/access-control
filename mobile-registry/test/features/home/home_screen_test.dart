import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/theme/app_theme.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets('abre na tela inicial com o servidor configurado', (tester) async {
    final handle = tester.ensureSemantics();
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Configurar servidor'), findsOneWidget);
    expect(find.bySemanticsLabel('Servidor configurado: http://10.0.2.2:3000/api'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('configuração é acessível antes do login', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configurar servidor'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Configurações'), findsOneWidget);
  });

  group('acessibilidade (US-21)', () {
    testWidgets('botões têm área de toque ampla e rótulo em texto', (tester) async {
      final env = await buildTestEnv(tester);
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppTheme.buttonHeight));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.descendant(of: find.byType(FilledButton), matching: find.text('Configurar servidor')), findsOneWidget);
    });

    testWidgets('elementos principais têm rótulos semânticos', (tester) async {
      final handle = tester.ensureSemantics();
      final env = await buildTestEnv(tester);
      await tester.pumpWidget(env.widget);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Bem-vindo'), findsOneWidget);
      expect(find.bySemanticsLabel('Configurar servidor'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('respeita o tamanho de texto do sistema sem estourar o layout', (tester) async {
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
      // Salva as configurações e dispara o teste de conexão (assíncrono).
      for (var i = 0;
          i < 20 && find.byType(CircularProgressIndicator).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Carregando: spinner visível e os dois botões desabilitados.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar'));
      final test = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Salvar e testar conexão'),
      );
      expect(save.onPressed, isNull);
      expect(test.onPressed, isNull);

      // Resposta chega: spinner some e o botão volta a funcionar.
      gate.complete(
        ResponseBody.fromString(
          '{"status":"ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Conexão com o servidor funcionando.'), findsOneWidget);
    });
  });
}
