import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/core/nfc/nfc_service.dart';
import 'package:mobile_registry/features/users/presentation/user_form_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_nfc_service.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

Future<TestEnv> startApp(
  WidgetTester tester,
  RoutedAdapter adapter, {
  FakeNfcService? nfc,
}) async {
  final env = await buildTestEnv(
    tester,
    nfc: nfc,
    adapter: adapter,
    signedInAs: testAdmin,
    logicalSize: tallScreen, // lista e cartões inflados pela fonte de teste
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  return env;
}

Future<void> openEditForm(WidgetTester tester, String name) async {
  await tapVisible(tester, find.text(name));
}

Finder submitEdit() => find.widgetWithText(FilledButton, 'Salvar alterações');

Map<String, Object?> bodyOf(RoutedAdapter a, String method) => Map<String, Object?>.from(
      a.requests.lastWhere((r) => r.method == method).data as Map,
    );

RoutedAdapter baseApi({Map<String, FakeHandler> extra = const {}}) => RoutedAdapter({
      'GET /users': usersPage([userJson(), userJson(id: 'u1', name: 'Ana Admin', email: 'admin@teste.com', role: 'ADMIN')], total: 2),
      'GET /users/u-1': FakeAdapter.json(200, detailJson()),
      ...extra,
    });

void main() {
  group('edição (US-09)', () {
    testWidgets('abre com os dados atuais preenchidos', (tester) async {
      await startApp(tester, baseApi());
      await openEditForm(tester, 'Maria Silva');

      expect(find.text('Editar usuário'), findsOneWidget);
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('maria@teste.com'), findsOneWidget);
      expect(find.text('12345678900'), findsOneWidget);
      expect(find.text('11999990000'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(chip('Condômino')).selected,
        isTrue,
      );
      expect(submitEdit(), findsOneWidget);
      // Senha começa em branco e é opcional.
      expect(field('Nova senha (opcional)'), findsOneWidget);
    });

    testWidgets('mostra carregamento e, se falhar, permite tentar de novo', (tester) async {
      var fail = true;
      final adapter = baseApi(extra: {
        'GET /users/u-1': (o) => fail
            ? FakeAdapter.fail(DioExceptionType.connectionError)(o)
            : FakeAdapter.json(200, detailJson())(o),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      expect(find.text(ApiException.networkMessage), findsOneWidget);
      expect(submitEdit(), findsNothing);

      fail = false;
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Tentar novamente'));

      expect(find.text(ApiException.networkMessage), findsNothing);
      expect(submitEdit(), findsOneWidget);
    });

    testWidgets('sem alterações, avisa e não envia', (tester) async {
      final adapter = baseApi();
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, submitEdit());

      expect(find.text('Nenhuma alteração para salvar.'), findsOneWidget);
      expect(adapter.callsTo('PUT /users/u-1'), 0);
      expect(find.text('Salvar as alterações?'), findsNothing);
    });

    testWidgets('só salva depois da confirmação; "Cancelar" não envia', (tester) async {
      final adapter = baseApi(extra: {
        'PUT /users/u-1': FakeAdapter.json(200, userJson(name: 'Maria Souza')),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tester.enterText(field('Nome completo'), 'Maria Souza');
      await tapVisible(tester, submitEdit());
      expect(find.text('Salvar as alterações?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('PUT /users/u-1'), 0);
      expect(find.byType(UserFormScreen), findsOneWidget);
    });

    testWidgets('confirmando, envia só o campo alterado e volta com mensagem de sucesso',
        (tester) async {
      final adapter = baseApi(extra: {
        'PUT /users/u-1': FakeAdapter.json(200, userJson(name: 'Maria Souza')),
      });
      await startApp(tester, adapter);
      final before = adapter.callsTo('GET /users');
      await openEditForm(tester, 'Maria Silva');

      await tester.enterText(field('Nome completo'), 'Maria Souza');
      await tapVisible(tester, submitEdit());
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(bodyOf(adapter, 'PUT'), {'name': 'Maria Souza'});
      expect(find.text('Alterações salvas.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(adapter.callsTo('GET /users'), before + 1);
    });

    testWidgets('troca de perfil, e-mail e nova senha são enviados; senha em branco, não',
        (tester) async {
      final adapter = baseApi(extra: {'PUT /users/u-1': FakeAdapter.json(200, userJson())});
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tester.enterText(field('E-mail'), 'NOVO@teste.com');
      await tapVisible(tester, chip('Administrador'));
      await tester.enterText(field('Nova senha (opcional)'), 'novasenha1');
      await tapVisible(tester, submitEdit());
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(bodyOf(adapter, 'PUT'), {
        'email': 'novo@teste.com',
        'role': 'ADMIN',
        'password': 'novasenha1',
      });
    });

    testWidgets('não deixa apagar documento ou telefone já informados', (tester) async {
      final adapter = baseApi();
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tester.enterText(field('Documento (opcional)'), '');
      await tapVisible(tester, submitEdit());

      expect(find.textContaining('Não é possível apagar este campo'), findsOneWidget);
      expect(adapter.callsTo('PUT /users/u-1'), 0);
    });

    testWidgets('erro do backend na edição aparece no campo', (tester) async {
      final adapter = baseApi(extra: {
        'PUT /users/u-1': apiError(400, 'VALIDATION_ERROR', 'Dados inválidos', [
          {'path': 'name', 'message': 'Nome muito curto (servidor)'},
        ]),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tester.enterText(field('Nome completo'), 'Maria Souza');
      await tapVisible(tester, submitEdit());
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Nome muito curto (servidor)'), findsOneWidget);
      expect(find.byType(UserFormScreen), findsOneWidget);
    });

    testWidgets('mostra a tag NFC e o rosto cadastrado, e avisa que o cadastro do rosto vem depois', (tester) async {
      final adapter = baseApi(extra: {
        'GET /users/u-1': FakeAdapter.json(200, detailJson(hasFace: true, tags: [tagJson()])),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Tag NFC e rosto'));

      expect(find.text('Tag NFC vinculada:'), findsOneWidget);
      expect(find.text('04A32F1B'), findsOneWidget);
      expect(find.text('Rosto cadastrado.'), findsOneWidget);
      expect(find.textContaining('próximas etapas'), findsOneWidget);
    });

    testWidgets('sem tag nem rosto, informa a situação', (tester) async {
      await startApp(tester, baseApi());
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Tag NFC e rosto'));

      expect(find.text('Nenhuma tag NFC vinculada.'), findsOneWidget);
      expect(find.text('Rosto não cadastrado.'), findsOneWidget);
    });
  });

  group('ativar e desativar (US-10)', () {
    RoutedAdapter statusApi({bool active = true}) => baseApi(extra: {
          'GET /users/u-1': FakeAdapter.json(200, detailJson(active: active)),
          'PATCH /users/u-1/status': (o) => FakeAdapter.json(
                200,
                userJson(active: (o.data as Map)['active'] as bool),
              )(o),
        });

    testWidgets('usuário ativo mostra a situação e o botão Desativar', (tester) async {
      await startApp(tester, statusApi());
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Situação'));

      expect(find.textContaining('Usuário ativo'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Desativar usuário'), findsOneWidget);
      expect(find.text('Reativar usuário'), findsNothing);
    });

    testWidgets('desativar pede confirmação e informa que o histórico é preservado',
        (tester) async {
      final adapter = statusApi();
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Desativar usuário'));

      expect(find.text('Desativar Maria Silva?'), findsOneWidget);
      expect(find.textContaining('histórico de acessos é preservado'), findsOneWidget);
      expect(adapter.callsTo('PATCH /users/u-1/status'), 0);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('PATCH /users/u-1/status'), 0);
      expect(find.textContaining('Usuário ativo'), findsOneWidget);
    });

    testWidgets('confirmar desativa, atualiza a tela e permite reativar', (tester) async {
      final adapter = statusApi();
      await startApp(tester, adapter);
      final before = adapter.callsTo('GET /users');
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Desativar usuário'));
      await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
      await tester.pumpAndSettle();

      expect(bodyOf(adapter, 'PATCH'), {'active': false});
      expect(find.text('Usuário desativado.'), findsOneWidget);
      expect(find.textContaining('Usuário inativo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reativar usuário'), findsOneWidget);
      expect(adapter.callsTo('GET /users'), before + 1); // lista atualizada

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reativar usuário'));

      expect(bodyOf(adapter, 'PATCH'), {'active': true});
      expect(find.text('Usuário reativado.'), findsOneWidget);
      expect(find.textContaining('Usuário ativo'), findsOneWidget);
    });

    testWidgets('usuário inativo abre já com o botão Reativar', (tester) async {
      final adapter = statusApi(active: false);
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Situação'));

      expect(find.textContaining('Usuário inativo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reativar usuário'), findsOneWidget);
      expect(find.text('Desativar usuário'), findsNothing);
    });

    testWidgets('o administrador não pode desativar a própria conta', (tester) async {
      final adapter = baseApi(extra: {
        'GET /users/u1': FakeAdapter.json(
          200,
          detailJson(id: 'u1', name: 'Ana Admin', email: 'admin@teste.com', role: 'ADMIN'),
        ),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Ana Admin');
      await tester.ensureVisible(find.text('Situação'));

      expect(find.text('Você não pode desativar a própria conta.'), findsOneWidget);
      expect(find.text('Desativar usuário'), findsNothing);
    });

    testWidgets('falha ao desativar mostra a mensagem e mantém a situação', (tester) async {
      final adapter = baseApi(extra: {
        'GET /users/u-1': FakeAdapter.json(200, detailJson()),
        'PATCH /users/u-1/status': apiError(500, 'INTERNAL_ERROR', 'stack'),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Desativar usuário'));
      await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
      await tester.pumpAndSettle();

      expect(find.text(ApiException.serverMessage), findsOneWidget);
      expect(find.textContaining('Usuário ativo'), findsOneWidget);
    });
  });


  group('tags NFC (US-12)', () {
    FakeHandler noContent() => (options) async => ResponseBody.fromString('', 204);

    RoutedAdapter tagApi({
      List<Map<String, Object?>> tags = const [],
      Map<String, FakeHandler> extra = const {},
    }) =>
        baseApi(extra: {
          'GET /users/u-1': FakeAdapter.json(200, detailJson(tags: tags)),
          ...extra,
        });

    Finder captureConfirm(String label) => find.widgetWithText(FilledButton, label);

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpAndSettle();
    }

    testWidgets('sem tag: informa e oferece vincular', (tester) async {
      await startApp(tester, tagApi());
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Tag NFC e rosto'));

      expect(find.text('Nenhuma tag NFC vinculada.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Vincular tag NFC'), findsOneWidget);
      expect(find.text('Substituir'), findsNothing);
    });

    testWidgets('mostra cada tag com Substituir e Remover', (tester) async {
      await startApp(tester, tagApi(tags: [tagJson()]));
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Tag NFC e rosto'));

      expect(find.text('Tag NFC vinculada:'), findsOneWidget);
      expect(find.text('04A32F1B'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Substituir'), findsOneWidget);
      expect(find.text('Remover'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Vincular outra tag NFC'), findsOneWidget);
    });

    testWidgets('vincular: lê a tag, envia o UID e mostra a tag na lista', (tester) async {
      final adapter = tagApi(extra: {
        'POST /users/u-1/tags': FakeAdapter.json(201, tagJson(id: 't-7', uid: '04B1C2D3')),
      });
      final nfc = FakeNfcService(script: ['04B1C2D3']);
      await startApp(tester, adapter, nfc: nfc);
      final listCalls = adapter.callsTo('GET /users');
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Vincular tag NFC'));
      expect(find.text('Tag lida com sucesso.'), findsOneWidget);
      await tester.tap(captureConfirm('Usar esta tag'));
      await pump(tester);

      expect(bodyOf(adapter, 'POST'), {'uid': '04B1C2D3'});
      expect(find.text('04B1C2D3'), findsOneWidget);
      expect(find.text('Tag vinculada.'), findsOneWidget);
      expect(find.text('Nenhuma tag NFC vinculada.'), findsNothing);
      expect(adapter.callsTo('GET /users'), listCalls + 1); // lista atualizada
    });

    testWidgets('vincular: cancelar a leitura não envia nada', (tester) async {
      final adapter = tagApi();
      final nfc = FakeNfcService(script: ['04B1C2D3']);
      await startApp(tester, adapter, nfc: nfc);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Vincular tag NFC'));
      await tester.tap(find.text('Cancelar'));
      await pump(tester);

      expect(adapter.callsTo('POST /users/u-1/tags'), 0);
    });

    testWidgets('vincular tag que o usuário já tem: avisa e não envia', (tester) async {
      final adapter = tagApi(tags: [tagJson()]);
      final nfc = FakeNfcService(script: ['04A32F1B']);
      await startApp(tester, adapter, nfc: nfc);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Vincular outra tag NFC'));
      await tester.tap(captureConfirm('Usar esta tag'));
      await pump(tester);

      expect(find.text('Esta tag já está vinculada a este usuário.'), findsOneWidget);
      expect(adapter.callsTo('POST /users/u-1/tags'), 0);
    });

    testWidgets('UID de outro usuário (409) mostra mensagem genérica, sem revelar o dono',
        (tester) async {
      final adapter = tagApi(extra: {
        'POST /users/u-1/tags': apiError(409, 'TAG_CONFLICT', 'Tag de Fulano de Tal'),
      });
      final nfc = FakeNfcService(script: ['04B1C2D3']);
      await startApp(tester, adapter, nfc: nfc);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Vincular tag NFC'));
      await tester.tap(captureConfirm('Usar esta tag'));
      await pump(tester);

      expect(find.text('Esta tag já está cadastrada.'), findsOneWidget);
      expect(find.textContaining('Fulano'), findsNothing);
      expect(find.text('Nenhuma tag NFC vinculada.'), findsOneWidget);
    });

    testWidgets('remover: pede confirmação; cancelar não remove', (tester) async {
      final adapter = tagApi(tags: [tagJson()]);
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.text('Remover'));
      expect(find.text('Remover a tag?'), findsOneWidget);
      expect(find.textContaining('deixará de entrar com ela'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await pump(tester);

      expect(adapter.callsTo('DELETE /users/u-1/tags/t-1'), 0);
      expect(find.text('04A32F1B'), findsOneWidget);
    });

    testWidgets('remover: confirmar desvincula a tag', (tester) async {
      final adapter = tagApi(tags: [tagJson()], extra: {
        'DELETE /users/u-1/tags/t-1': noContent(),
      });
      await startApp(tester, adapter);
      final listCalls = adapter.callsTo('GET /users');
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.text('Remover'));
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await pump(tester);

      expect(adapter.callsTo('DELETE /users/u-1/tags/t-1'), 1);
      expect(find.text('04A32F1B'), findsNothing);
      expect(find.text('Nenhuma tag NFC vinculada.'), findsOneWidget);
      expect(find.text('Tag removida.'), findsOneWidget);
      expect(adapter.callsTo('GET /users'), listCalls + 1);
    });

    testWidgets('remover com falha mostra o erro e mantém a tag', (tester) async {
      final adapter = tagApi(tags: [tagJson()], extra: {
        'DELETE /users/u-1/tags/t-1': apiError(500, 'INTERNAL_ERROR', 'x'),
      });
      await startApp(tester, adapter);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.text('Remover'));
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await pump(tester);

      expect(find.text(ApiException.serverMessage), findsOneWidget);
      expect(find.text('04A32F1B'), findsOneWidget);
    });

    group('substituir', () {
      Future<void> startReplace(WidgetTester tester, RoutedAdapter adapter, FakeNfcService nfc) async {
        await startApp(tester, adapter, nfc: nfc);
        await openEditForm(tester, 'Maria Silva');
        await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Substituir'));
        await tester.tap(captureConfirm('Usar a nova tag'));
        await pump(tester);
      }

      testWidgets('vincula a nova, remove a antiga e mostra só a nova', (tester) async {
        final adapter = tagApi(tags: [tagJson()], extra: {
          'POST /users/u-1/tags': FakeAdapter.json(201, tagJson(id: 't-2', uid: '0402ABCD')),
          'DELETE /users/u-1/tags/t-1': noContent(),
        });
        await startReplace(tester, adapter, FakeNfcService(script: ['0402ABCD']));

        expect(find.text('Substituir a tag?'), findsOneWidget);
        expect(find.textContaining('04A32F1B deixará de funcionar'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Substituir'));
        await pump(tester);

        // A nova é vinculada ANTES de a antiga ser removida.
        final writes = adapter.requests
            .where((r) => r.method == 'POST' || r.method == 'DELETE')
            .map((r) => '${r.method} ${r.path}');
        expect(writes, ['POST /users/u-1/tags', 'DELETE /users/u-1/tags/t-1']);
        expect(find.text('0402ABCD'), findsOneWidget);
        expect(find.text('04A32F1B'), findsNothing);
        expect(find.text('Tag substituída.'), findsOneWidget);
      });

      testWidgets('cancelar a confirmação não altera nada', (tester) async {
        final adapter = tagApi(tags: [tagJson()]);
        await startReplace(tester, adapter, FakeNfcService(script: ['0402ABCD']));

        await tester.tap(find.text('Cancelar'));
        await pump(tester);

        expect(adapter.callsTo('POST /users/u-1/tags'), 0);
        expect(find.text('04A32F1B'), findsOneWidget);
      });

      testWidgets('ler a mesma tag que já está vinculada avisa e não envia', (tester) async {
        final adapter = tagApi(tags: [tagJson()]);
        await startReplace(tester, adapter, FakeNfcService(script: ['04A32F1B']));

        expect(find.text('Esta já é a tag atual deste usuário.'), findsOneWidget);
        expect(adapter.callsTo('POST /users/u-1/tags'), 0);
      });

      testWidgets('nova tag com conflito: nada muda e a antiga continua valendo', (tester) async {
        final adapter = tagApi(tags: [tagJson()], extra: {
          'POST /users/u-1/tags': apiError(409, 'TAG_CONFLICT', 'x'),
        });
        await startReplace(tester, adapter, FakeNfcService(script: ['0402ABCD']));
        await tester.tap(find.widgetWithText(FilledButton, 'Substituir'));
        await pump(tester);

        expect(find.text('Esta tag já está cadastrada.'), findsOneWidget);
        expect(adapter.callsTo('DELETE /users/u-1/tags/t-1'), 0);
        expect(find.text('04A32F1B'), findsOneWidget);
      });

      testWidgets('nova vinculada mas antiga não removida: avisa e mostra as duas', (tester) async {
        final adapter = tagApi(tags: [tagJson()], extra: {
          'POST /users/u-1/tags': FakeAdapter.json(201, tagJson(id: 't-2', uid: '0402ABCD')),
          'DELETE /users/u-1/tags/t-1': apiError(500, 'INTERNAL_ERROR', 'x'),
        });
        await startReplace(tester, adapter, FakeNfcService(script: ['0402ABCD']));
        await tester.tap(find.widgetWithText(FilledButton, 'Substituir'));
        await pump(tester);

        expect(find.textContaining('A nova tag foi vinculada, mas não foi possível remover a antiga'),
            findsOneWidget);
        expect(find.text('0402ABCD'), findsOneWidget);
        expect(find.text('04A32F1B'), findsOneWidget);
      });
    });

    testWidgets('NFC desligado ao vincular: mensagem clara e nada é enviado', (tester) async {
      final adapter = tagApi();
      final nfc = FakeNfcService(status: NfcHardwareStatus.disabledOrUnavailable);
      await startApp(tester, adapter, nfc: nfc);
      await openEditForm(tester, 'Maria Silva');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Vincular tag NFC'));

      expect(find.textContaining('O NFC não está disponível'), findsOneWidget);
      expect(adapter.callsTo('POST /users/u-1/tags'), 0);
    });

    testWidgets('mostra a situação do rosto e avisa que o cadastro vem depois', (tester) async {
      await startApp(tester, tagApi());
      await openEditForm(tester, 'Maria Silva');
      await tester.ensureVisible(find.text('Tag NFC e rosto'));

      expect(find.text('Rosto não cadastrado.'), findsOneWidget);
      expect(find.textContaining('próximas etapas'), findsOneWidget);
    });
  });

  testWidgets('texto em 2x não estoura o formulário de edição', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await startApp(tester, baseApi());
    await openEditForm(tester, 'Maria Silva');

    expect(tester.takeException(), isNull);
    expect(find.byType(UserFormScreen), findsOneWidget);
  });
}
