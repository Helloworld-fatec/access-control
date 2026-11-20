import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/users/presentation/user_form_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

final defaultUsers = [
  userJson(hasFace: true, nfcTagCount: 1),
  userJson(
    id: 'u-2',
    name: 'João Souza',
    email: 'joao@teste.com',
    document: null,
    role: 'VISITOR',
    active: false,
    hasFace: false,
    nfcTagCount: 0,
  ),
];

Finder searchField() =>
    find.widgetWithText(TextField, 'Buscar por nome ou documento');

Future<TestEnv> startApp(WidgetTester tester, RoutedAdapter adapter) async {
  final env = await buildTestEnv(
    tester,
    adapter: adapter,
    signedInAs: testAdmin,
    logicalSize: tallScreen, // ver o comentário de tallScreen
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  return env;
}

/// Os filtros começam recolhidos: abre o painel para usar os botões.
Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.text('Filtros'));
  await tester.pumpAndSettle();
}

Map<String, String> lastQuery(RoutedAdapter a) => a.requests
    .lastWhere((r) => r.method == 'GET' && r.path == '/users')
    .uri
    .queryParameters;

void main() {
  testWidgets('mostra os usuários com perfil, situação, tag e rosto', (tester) async {
    final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
    await startApp(tester, adapter);

    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.text('João Souza'), findsOneWidget);
    expect(find.text('2 usuários'), findsOneWidget);
    // Maria: condômina ativa, com tag e com rosto.
    expect(find.text('Condômino'), findsWidgets); // chip do filtro + cartão
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Com tag NFC'), findsOneWidget);
    expect(find.text('Com rosto'), findsOneWidget);
    // João: visitante inativo, sem tag e sem rosto.
    expect(find.text('Inativo'), findsOneWidget);
    expect(find.text('Sem tag NFC'), findsOneWidget);
    expect(find.text('Sem rosto'), findsOneWidget);
    expect(find.textContaining('12345678900'), findsOneWidget);
    expect(find.text('maria@teste.com'), findsNothing); // e-mail vem junto do documento
    expect(find.textContaining('maria@teste.com'), findsOneWidget);
  });

  testWidgets('sem a informação de tag e rosto na API, os indicadores não aparecem',
      (tester) async {
    final adapter = RoutedAdapter({'GET /users': usersPage([userJson()])});
    await startApp(tester, adapter);

    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.textContaining('tag NFC'), findsNothing);
    expect(find.textContaining('rosto'), findsNothing);
  });

  testWidgets('cartão tem rótulo único para leitores de tela', (tester) async {
    final handle = tester.ensureSemantics();
    final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
    await startApp(tester, adapter);

    expect(
      find.bySemanticsLabel('Maria Silva, Condômino, ativo, com tag NFC, com rosto'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('João Souza, Visitante, inativo, sem tag NFC, sem rosto'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('mostra carregamento enquanto a lista não chega', (tester) async {
    final gate = Completer<ResponseBody>();
    final adapter = RoutedAdapter({'GET /users': (o) => gate.future});
    final env = await buildTestEnv(
      tester,
      adapter: adapter,
      signedInAs: testAdmin,
      logicalSize: tallScreen,
    );
    await tester.pumpWidget(env.widget);
    await tester.pump();
    await tester.pump();

    expect(find.text('Carregando usuários...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(ResponseBody.fromString(
      '{"data":[],"page":1,"pageSize":20,"total":0,"totalPages":1}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Carregando usuários...'), findsNothing);
  });

  group('lista vazia', () {
    testWidgets('sem filtros, convida a cadastrar', (tester) async {
      await startApp(tester, RoutedAdapter({'GET /users': usersPage([])}));

      expect(find.text('Nenhum usuário encontrado.'), findsOneWidget);
      expect(find.textContaining('Novo usuário'), findsWidgets);
      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('com busca, oferece limpar os filtros', (tester) async {
      final adapter = RoutedAdapter({
        'GET /users': (o) => o.uri.queryParameters.containsKey('search')
            ? usersPage([])(o)
            : usersPage(defaultUsers, total: 2)(o),
      });
      await startApp(tester, adapter);

      await tester.enterText(searchField(), 'zzz');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum usuário encontrado.'), findsOneWidget);
      expect(find.text('Tente outra busca ou limpe os filtros.'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Limpar filtros'));

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(lastQuery(adapter).containsKey('search'), isFalse);
      // O campo de busca também é limpo.
      expect(tester.widget<TextField>(searchField()).controller!.text, isEmpty);
    });
  });

  group('erro', () {
    testWidgets('mostra a mensagem e o botão tentar novamente', (tester) async {
      var fail = true;
      final adapter = RoutedAdapter({
        'GET /users': (o) => fail
            ? FakeAdapter.fail(DioExceptionType.connectionError)(o)
            : usersPage(defaultUsers, total: 2)(o),
      });
      await startApp(tester, adapter);

      expect(find.text(ApiException.networkMessage), findsOneWidget);
      expect(find.text('Maria Silva'), findsNothing);

      fail = false;
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Tentar novamente'));

      expect(find.text(ApiException.networkMessage), findsNothing);
      expect(find.text('Maria Silva'), findsOneWidget);
    });

    testWidgets('erro 500 não mostra texto técnico', (tester) async {
      await startApp(
        tester,
        RoutedAdapter({'GET /users': apiError(500, 'INTERNAL_ERROR', 'stack trace')}),
      );
      expect(find.text(ApiException.serverMessage), findsOneWidget);
      expect(find.textContaining('stack'), findsNothing);
    });
  });

  group('busca e filtros', () {
    testWidgets('digitar na busca espera uma pausa e depois consulta o servidor', (tester) async {
      final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
      await startApp(tester, adapter);
      final before = adapter.callsTo('GET /users');

      await tester.enterText(searchField(), 'mar');
      await tester.pump(const Duration(milliseconds: 100));
      expect(adapter.callsTo('GET /users'), before); // ainda esperando

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(adapter.callsTo('GET /users'), before + 1);
      expect(lastQuery(adapter)['search'], 'mar');
    });

    testWidgets('digitar várias letras seguidas gera uma única consulta', (tester) async {
      final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
      await startApp(tester, adapter);
      final before = adapter.callsTo('GET /users');

      await tester.enterText(searchField(), 'm');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(searchField(), 'ma');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.enterText(searchField(), 'mar');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(adapter.callsTo('GET /users'), before + 1);
      expect(lastQuery(adapter)['search'], 'mar');
    });

    testWidgets('botão X limpa a busca e recarrega', (tester) async {
      final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
      await startApp(tester, adapter);
      await tester.enterText(searchField(), 'mar');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(lastQuery(adapter)['search'], 'mar');

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();

      expect(lastQuery(adapter).containsKey('search'), isFalse);
      expect(tester.widget<TextField>(searchField()).controller!.text, isEmpty);
    });

    testWidgets('os filtros começam recolhidos, deixando a lista logo à vista', (tester) async {
      await startApp(tester, RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)}));

      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Nenhum filtro aplicado'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Condômino'), findsNothing);
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('João Souza'), findsOneWidget);
    });

    testWidgets('o botão Filtros abre e fecha o painel', (tester) async {
      await startApp(tester, RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)}));

      await openFilters(tester);
      expect(find.widgetWithText(ChoiceChip, 'Condômino'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Inativos'), findsOneWidget);

      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Condômino'), findsNothing);
    });

    testWidgets('o resumo mostra os filtros aplicados mesmo com o painel fechado', (tester) async {
      await startApp(tester, RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)}));
      await openFilters(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Condômino'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Inativos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filtros')); // fecha o painel
      await tester.pumpAndSettle();

      expect(find.text('Condômino | Inativos'), findsOneWidget);
      expect(find.text('Nenhum filtro aplicado'), findsNothing);
    });

    for (final (label, value) in [
      ('Administrador', 'ADMIN'),
      ('Condômino', 'RESIDENT'),
      ('Visitante', 'VISITOR'),
    ]) {
      testWidgets('filtro de perfil "$label" envia role=$value', (tester) async {
        final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
        await startApp(tester, adapter);
        await openFilters(tester);

        await tester.tap(find.widgetWithText(ChoiceChip, label));
        await tester.pumpAndSettle();

        expect(lastQuery(adapter)['role'], value);
      });
    }

    testWidgets('filtros de situação enviam active=true/false e "Todas" remove', (tester) async {
      final adapter = RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)});
      await startApp(tester, adapter);
      await openFilters(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Inativos'));
      await tester.pumpAndSettle();
      expect(lastQuery(adapter)['active'], 'false');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ativos'));
      await tester.pumpAndSettle();
      expect(lastQuery(adapter)['active'], 'true');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
      await tester.pumpAndSettle();
      expect(lastQuery(adapter).containsKey('active'), isFalse);
    });
  });

  group('paginação', () {
    RoutedAdapter twoPages() => RoutedAdapter({
          'GET /users': (o) {
            if (o.uri.queryParameters['page'] == '2') {
              return usersPage(
                [userJson(id: 'u-3', name: 'Carla Dias')],
                page: 2,
                total: 3,
                totalPages: 2,
              )(o);
            }
            return usersPage(defaultUsers, total: 3, totalPages: 2)(o);
          },
        });

    testWidgets('"Carregar mais" acrescenta a próxima página e some no fim', (tester) async {
      final adapter = twoPages();
      await startApp(tester, adapter);
      expect(find.text('Carla Dias'), findsNothing);
      expect(find.text('3 usuários'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Carregar mais'));

      expect(lastQuery(adapter)['page'], '2');
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('Carla Dias'), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('sem próxima página, não há botão', (tester) async {
      await startApp(tester, RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)}));
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('falha ao carregar mais mostra aviso e mantém a lista', (tester) async {
      final adapter = RoutedAdapter({
        'GET /users': (o) => o.uri.queryParameters['page'] == '2'
            ? FakeAdapter.fail(DioExceptionType.connectionError)(o)
            : usersPage(defaultUsers, total: 3, totalPages: 2)(o),
      });
      await startApp(tester, adapter);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Carregar mais'));

      expect(find.text(ApiException.networkMessage), findsOneWidget);
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Carregar mais'), findsOneWidget);
    });
  });

  testWidgets('tocar em um usuário abre a edição com os dados dele', (tester) async {
    final adapter = RoutedAdapter({
      'GET /users': usersPage(defaultUsers, total: 2),
      'GET /users/u-1': FakeAdapter.json(200, detailJson()),
    });
    await startApp(tester, adapter);

    await tapVisible(tester, find.text('Maria Silva'));

    expect(find.byType(UserFormScreen), findsOneWidget);
    expect(find.text('Editar usuário'), findsOneWidget);
    expect(adapter.callsTo('GET /users/u-1'), 1);
  });

  testWidgets('texto em 2x não estoura o layout da lista', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await startApp(
      tester,
      RoutedAdapter({'GET /users': usersPage(defaultUsers, total: 2)}),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Maria Silva'), findsOneWidget);
  });
}
