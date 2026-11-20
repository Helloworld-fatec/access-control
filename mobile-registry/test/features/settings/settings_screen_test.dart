import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/config/settings_repository.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';

const hostLabel = 'Endereço do servidor (IP)';
const portLabel = 'Porta do servidor';
const photoLabel = 'Tamanho máximo da foto (KB)';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('mostra os valores padrão (50 KB, 3 capturas)', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    expect(find.text('10.0.2.2'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    expect(find.text('Salvar e testar conexão'), findsOneWidget);
  });

  testWidgets('IP inválido mostra mensagem clara e não salva', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    await tester.enterText(field(hostLabel), '999.1.1.1');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));

    expect(find.text('Endereço inválido. Use o formato 192.168.0.10.'), findsOneWidget);
    expect(find.text('Confira os campos destacados e tente de novo.'), findsOneWidget);
    expect(env.prefs.getString(SettingsRepository.hostKey), isNull);
  });

  testWidgets('porta inválida mostra mensagem clara', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    await tester.enterText(field(portLabel), '70000');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));

    expect(find.text('Porta inválida. Use um número de 1 a 65535.'), findsOneWidget);
  });

  testWidgets('foto fora do limite mostra mensagem clara', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    await tester.enterText(field(photoLabel), '5');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));

    expect(find.text('Informe um tamanho entre 10 e 500 KB.'), findsOneWidget);
  });

  testWidgets('salva IP, porta, foto e capturas em shared_preferences', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    await tester.enterText(field(hostLabel), '192.168.0.10');
    await tester.enterText(field(portLabel), '8080');
    await tester.enterText(field(photoLabel), '80');
    
    // Seleciona o valor 5 no SegmentedButton
    await tapVisible(tester, find.descendant(
      of: find.byType(SegmentedButton<int>),
      matching: find.text('5'),
    ));
    
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Salvar'));

    expect(
      find.text('Configurações salvas. Elas já valem para as próximas ações.'),
      findsOneWidget,
    );
    expect(env.prefs.getString(SettingsRepository.hostKey), '192.168.0.10');
    expect(env.prefs.getInt(SettingsRepository.portKey), 8080);
    expect(env.prefs.getInt(SettingsRepository.maxPhotoKbKey), 80);
    expect(env.prefs.getInt(SettingsRepository.faceSamplesKey), 5);
  });

  testWidgets('"Salvar e testar" usa o endereço novo e mostra sucesso', (tester) async {
    final env = await buildTestEnv(tester, home: const SettingsScreen());
    await tester.pumpWidget(env.widget);

    await tester.enterText(field(hostLabel), '192.168.0.10');
    await tester.enterText(field(portLabel), '8080');
    await tapVisible(tester, find.text('Salvar e testar conexão'));

    expect(find.text('Conexão com o servidor funcionando.'), findsOneWidget);
    expect(
      env.adapter.requests.last.uri.toString(),
      'http://192.168.0.10:8080/api/health',
    );
  });

  testWidgets('servidor fora do ar mostra mensagem em linguagem simples', (tester) async {
    final env = await buildTestEnv(
      tester,
      home: const SettingsScreen(),
      adapter: FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]),
    );
    await tester.pumpWidget(env.widget);

    await tapVisible(tester, find.text('Salvar e testar conexão'));

    expect(find.text(ApiException.networkMessage), findsOneWidget);
    // 1 chamada original + 3 novas tentativas automáticas
    expect(env.adapter.calls, 4);
  });

  testWidgets('"Restaurar valores padrão" repõe os campos', (tester) async {
    final env = await buildTestEnv(
      tester,
      home: const SettingsScreen(),
      initialPrefs: {
        SettingsRepository.hostKey: '172.16.0.5',
        SettingsRepository.portKey: 4000,
      },
    );
    await tester.pumpWidget(env.widget);
    expect(find.text('172.16.0.5'), findsOneWidget);

    await tapVisible(tester, find.text('Restaurar valores padrão'));

    expect(find.text('10.0.2.2'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
  });
}