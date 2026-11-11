import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/nfc/nfc_service.dart';
import 'package:mobile_registry/features/home/presentation/home_screen.dart';
import 'package:mobile_registry/features/users/presentation/new_user_wizard_screen.dart';
import 'package:mobile_registry/features/users/presentation/user_form_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_nfc_service.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);
Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
Finder primary(String label) => find.widgetWithText(FilledButton, label);
Finder secondary(String label) => find.widgetWithText(OutlinedButton, label);

RoutedAdapter api({Map<String, FakeHandler> extra = const {}}) => RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'POST /users': FakeAdapter.json(
        201,
        userJson(id: 'u-9', name: 'Ana Souza', email: 'ana@teste.com'),
      ),
      'POST /users/u-9/tags': FakeAdapter.json(201, tagJson(id: 't-9', uid: '04A32F1B')),
      'GET /users/u-9': FakeAdapter.json(200, detailJson(id: 'u-9', name: 'Ana Souza')),
      ...extra,
    });

Future<void> startWizard(
  WidgetTester tester,
  RoutedAdapter adapter, {
  FakeNfcService? nfc,
}) async {
  final env = await buildTestEnv(
    tester,
    adapter: adapter,
    nfc: nfc,
    signedInAs: testAdmin,
    logicalSize: tallScreen,
  );
  await tester.pumpWidget(env.widget);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Novo usuário'));
  await tester.pumpAndSettle();
}

Future<void> fillStep1(
  WidgetTester tester, {
  String name = 'Ana Souza',
  String email = 'ana@teste.com',
  String password = 'segredo1',
  String role = 'Condômino',
  String document = '',
  String phone = '',
}) async {
  await tester.enterText(field('Nome completo'), name);
  if (document.isNotEmpty) await tester.enterText(field('Documento (opcional)'), document);
  await tester.enterText(field('E-mail'), email);
  if (phone.isNotEmpty) await tester.enterText(field('Telefone (opcional)'), phone);
  await tapVisible(tester, chip(role));
  await tester.enterText(field('Senha'), password);
}

Future<void> next(WidgetTester tester, [String label = 'Avançar']) =>
    tapVisible(tester, primary(label));

/// Preenche a etapa 1 e vai até a revisão (lendo a tag, se [readTag]).
Future<void> goToReview(WidgetTester tester, {bool readTag = false}) async {
  await fillStep1(tester);
  await next(tester); // -> Tag NFC
  if (readTag) {
    await tapVisible(tester, primary('Ler tag NFC'));
    await tapVisible(tester, primary('Usar esta tag'));
    await next(tester); // -> Rosto
  } else {
    await next(tester, 'Pular esta etapa'); // -> Rosto
  }
  await next(tester); // -> Revisão
}

Map<String, Object?> bodyOf(RoutedAdapter a, String route) => Map<String, Object?>.from(
      a.requests.lastWhere((r) => '${r.method} ${r.path}' == route).data as Map,
    );

void main() {
  group('navegação e progresso', () {
    testWidgets('abre na etapa Dados, com o indicador de progresso', (tester) async {
      await startWizard(tester, api());

      expect(find.byType(NewUserWizardScreen), findsOneWidget);
      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      for (final label in ['Nome completo', 'Documento (opcional)', 'E-mail', 'Telefone (opcional)', 'Senha']) {
        expect(field(label), findsOneWidget, reason: label);
      }
      for (final role in ['Administrador', 'Condômino', 'Visitante']) {
        expect(chip(role), findsOneWidget, reason: role);
      }
      expect(primary('Avançar'), findsOneWidget);
      expect(secondary('Cancelar'), findsOneWidget);
    });

    testWidgets('a etapa 1 valida antes de avançar', (tester) async {
      final adapter = api();
      await startWizard(tester, adapter);

      await next(tester);

      expect(find.text('Informe o nome completo.'), findsOneWidget);
      expect(find.text('Informe o e-mail.'), findsOneWidget);
      expect(find.text('Escolha o perfil.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
      expect(find.text('Confira os campos destacados e tente de novo.'), findsOneWidget);
      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      expect(adapter.callsTo('POST /users'), 0);
    });

    testWidgets('e-mail inválido e senha curta impedem de avançar', (tester) async {
      await startWizard(tester, api());

      await fillStep1(tester, email: 'ana', password: '123');
      await next(tester);

      expect(find.text('E-mail inválido. Exemplo: nome@exemplo.com.'), findsOneWidget);
      expect(find.text('A senha deve ter ao menos 6 caracteres.'), findsOneWidget);
      expect(find.text('Etapa 1 de 4'), findsOneWidget);
    });

    testWidgets('percorre Tag NFC, Rosto e Revisão', (tester) async {
      await startWizard(tester, api());
      await fillStep1(tester);

      await next(tester);
      expect(find.text('Etapa 2 de 4'), findsOneWidget);
      expect(find.text('Tag NFC (opcional)'), findsOneWidget);
      expect(primary('Pular esta etapa'), findsOneWidget);

      await next(tester, 'Pular esta etapa');
      expect(find.text('Etapa 3 de 4'), findsOneWidget);
      expect(find.text('Rosto (opcional)'), findsOneWidget);
      expect(find.textContaining('próximas etapas'), findsOneWidget);

      await next(tester);
      expect(find.text('Etapa 4 de 4'), findsOneWidget);
      expect(find.text('Confira os dados'), findsOneWidget);
      expect(primary('Confirmar cadastro'), findsOneWidget);
    });

    testWidgets('a revisão mostra os dados e esconde a senha', (tester) async {
      await startWizard(tester, api());
      await fillStep1(tester, document: '999', phone: '11988887777', role: 'Visitante');
      await next(tester);
      await next(tester, 'Pular esta etapa');
      await next(tester);

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
      expect(find.text('ana@teste.com'), findsOneWidget);
      expect(find.text('11988887777'), findsOneWidget);
      expect(find.text('Visitante'), findsOneWidget);
      expect(find.text('Definida (não é mostrada)'), findsOneWidget);
      expect(find.text('segredo1'), findsNothing);
      expect(find.text('Nenhuma (vincule depois, pela edição)'), findsOneWidget);
    });

    testWidgets('documento e telefone em branco aparecem como "Não informado"', (tester) async {
      await startWizard(tester, api());
      await goToReview(tester);
      expect(find.text('Não informado'), findsNWidgets(2));
    });

    testWidgets('Voltar preserva tudo o que foi digitado', (tester) async {
      await startWizard(tester, api());
      await goToReview(tester);

      for (final stepLabel in ['Etapa 3 de 4', 'Etapa 2 de 4', 'Etapa 1 de 4']) {
        await tapVisible(tester, secondary('Voltar').evaluate().isNotEmpty
            ? secondary('Voltar')
            : secondary('Cancelar'));
        expect(find.text(stepLabel), findsOneWidget);
      }

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('ana@teste.com'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(chip('Condômino')).selected, isTrue);
    });

    testWidgets('o botão voltar do aparelho volta uma etapa e, na primeira, sai', (tester) async {
      await startWizard(tester, api());
      await fillStep1(tester);
      await next(tester);
      expect(find.text('Etapa 2 de 4'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      expect(find.byType(NewUserWizardScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(NewUserWizardScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Cancelar sai do assistente sem enviar nada', (tester) async {
      final adapter = api();
      await startWizard(tester, adapter);

      await tapVisible(tester, secondary('Cancelar'));

      expect(find.byType(NewUserWizardScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(adapter.callsTo('POST /users'), 0);
    });

    testWidgets('o indicador tem rótulo para leitores de tela', (tester) async {
      final handle = tester.ensureSemantics();
      await startWizard(tester, api());
      await fillStep1(tester);
      await next(tester);

      expect(find.bySemanticsLabel('Etapa 2 de 4: Tag NFC'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('texto em 2x não estoura o layout nas etapas', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await startWizard(tester, api());
      expect(tester.takeException(), isNull);
      await goToReview(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Etapa 4 de 4'), findsOneWidget);
    });
  });

  group('etapa Tag NFC', () {
    Future<void> toTagStep(WidgetTester tester) async {
      await fillStep1(tester);
      await next(tester);
    }

    testWidgets('lê a tag, mostra o código e guarda para a revisão', (tester) async {
      await startWizard(tester, api(), nfc: FakeNfcService(script: ['04A32F1B']));
      await toTagStep(tester);

      await tapVisible(tester, primary('Ler tag NFC'));
      expect(find.text('Tag lida com sucesso.'), findsOneWidget);
      await tapVisible(tester, primary('Usar esta tag'));

      expect(find.text('Tag lida'), findsOneWidget);
      expect(find.text('04A32F1B'), findsOneWidget);
      expect(primary('Avançar'), findsOneWidget); // não é mais "Pular"
      expect(find.text('Pular esta etapa'), findsNothing);

      await next(tester);
      await next(tester);
      expect(find.text('04A32F1B'), findsOneWidget); // na revisão
    });

    testWidgets('"Não vincular tag" desfaz a leitura', (tester) async {
      await startWizard(tester, api(), nfc: FakeNfcService(script: ['04A32F1B']));
      await toTagStep(tester);
      await tapVisible(tester, primary('Ler tag NFC'));
      await tapVisible(tester, primary('Usar esta tag'));

      await tapVisible(tester, find.text('Não vincular tag'));

      expect(find.text('04A32F1B'), findsNothing);
      expect(primary('Pular esta etapa'), findsOneWidget);
    });

    testWidgets('"Ler outra tag" troca o código', (tester) async {
      await startWizard(
        tester,
        api(),
        nfc: FakeNfcService(script: ['04A32F1B', '0402ABCD']),
      );
      await toTagStep(tester);
      await tapVisible(tester, primary('Ler tag NFC'));
      await tapVisible(tester, primary('Usar esta tag'));

      await tapVisible(tester, secondary('Ler outra tag'));
      await tapVisible(tester, primary('Usar esta tag'));

      expect(find.text('0402ABCD'), findsOneWidget);
      expect(find.text('04A32F1B'), findsNothing);
    });

    testWidgets('NFC desligado: mensagem clara e dá para seguir sem a tag', (tester) async {
      await startWizard(
        tester,
        api(),
        nfc: FakeNfcService(status: NfcHardwareStatus.disabledOrUnavailable),
      );
      await toTagStep(tester);

      await tapVisible(tester, primary('Ler tag NFC'));
      expect(find.textContaining('O NFC não está disponível'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(primary('Pular esta etapa'), findsOneWidget);
      await next(tester, 'Pular esta etapa');
      expect(find.text('Etapa 3 de 4'), findsOneWidget);
    });
  });

  group('confirmar o cadastro', () {
    testWidgets('sem tag: envia só o usuário, avisa e volta à lista atualizada', (tester) async {
      final adapter = api();
      await startWizard(tester, adapter);
      final listCalls = adapter.callsTo('GET /users');
      await fillStep1(
        tester,
        name: '  Ana Souza ',
        email: 'ANA@Teste.com',
        role: 'Visitante',
        document: '999',
        phone: '11988887777',
      );
      await next(tester);
      await next(tester, 'Pular esta etapa');
      await next(tester);

      await next(tester, 'Confirmar cadastro');

      expect(bodyOf(adapter, 'POST /users'), {
        'name': 'Ana Souza',
        'email': 'ana@teste.com',
        'password': 'segredo1',
        'role': 'VISITOR',
        'document': '999',
        'phone': '11988887777',
      });
      expect(adapter.callsTo('POST /users/u-9/tags'), 0);
      expect(find.text('Usuário cadastrado.'), findsOneWidget);
      expect(find.byType(NewUserWizardScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(adapter.callsTo('GET /users'), listCalls + 1);
    });

    testWidgets('com tag: cria o usuário e depois vincula a tag', (tester) async {
      final adapter = api();
      await startWizard(tester, adapter, nfc: FakeNfcService(script: ['04A32F1B']));
      await goToReview(tester, readTag: true);

      await next(tester, 'Confirmar cadastro');

      final writes = adapter.requests
          .where((r) => r.method == 'POST')
          .map((r) => r.path);
      expect(writes, ['/users', '/users/u-9/tags']);
      expect(bodyOf(adapter, 'POST /users/u-9/tags'), {'uid': '04A32F1B'});
      expect(find.text('Usuário cadastrado.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('erro de validação do servidor volta aos dados com o erro no campo', (tester) async {
      final adapter = api(extra: {
        'POST /users': apiError(400, 'VALIDATION_ERROR', 'Dados inválidos', [
          {'path': 'email', 'message': 'E-mail inválido (servidor)'},
        ]),
      });
      await startWizard(tester, adapter);
      await goToReview(tester);

      await next(tester, 'Confirmar cadastro');

      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      expect(find.text('E-mail inválido (servidor)'), findsOneWidget);
      expect(find.text('Confira os campos destacados e tente de novo.'), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget); // dados preservados
      expect(find.byType(NewUserWizardScreen), findsOneWidget);
    });

    testWidgets('e-mail repetido (409) volta aos dados e marca o e-mail', (tester) async {
      final adapter = api(extra: {
        'POST /users': apiError(409, 'USER_CONFLICT', 'E-mail ou documento já cadastrado'),
      });
      await startWizard(tester, adapter);
      await goToReview(tester);

      await next(tester, 'Confirmar cadastro');

      expect(find.text('Etapa 1 de 4'), findsOneWidget);
      // Uma vez no aviso e outra sob o campo e-mail.
      expect(find.text('E-mail ou documento já cadastrado'), findsNWidgets(2));
    });

    testWidgets('erro de servidor (500) fica na revisão e permite tentar de novo', (tester) async {
      final adapter = api(extra: {
        'POST /users': apiError(500, 'INTERNAL_ERROR', 'stack trace'),
      });
      await startWizard(tester, adapter);
      await goToReview(tester);

      await next(tester, 'Confirmar cadastro');

      expect(find.text(ApiException.serverMessage), findsOneWidget);
      expect(find.text('Etapa 4 de 4'), findsOneWidget);
      expect(primary('Confirmar cadastro'), findsOneWidget);

      adapter.routes['POST /users'] =
          FakeAdapter.json(201, userJson(id: 'u-9', name: 'Ana Souza'));
      await next(tester, 'Confirmar cadastro');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('servidor fora do ar mostra a mensagem e não perde os dados', (tester) async {
      final adapter = api(extra: {
        'POST /users': FakeAdapter.fail(DioExceptionType.connectionError),
      });
      await startWizard(tester, adapter);
      await goToReview(tester);

      await next(tester, 'Confirmar cadastro');

      expect(find.text(ApiException.networkMessage), findsOneWidget);
      expect(find.text('Ana Souza'), findsOneWidget);
    });

    testWidgets('durante o envio o botão fica bloqueado e há um único POST', (tester) async {
      final gate = Completer<ResponseBody>();
      final adapter = api(extra: {'POST /users': (o) => gate.future});
      await startWizard(tester, adapter);
      await goToReview(tester);

      await tester.ensureVisible(primary('Confirmar cadastro'));
      await tester.pumpAndSettle();
      await tester.tap(primary('Confirmar cadastro'));
      for (var i = 0;
          i < 20 && find.byType(CircularProgressIndicator).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(primary('Confirmar cadastro')).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(secondary('Voltar')).onPressed, isNull);
      expect(adapter.callsTo('POST /users'), 1);

      gate.complete(ResponseBody.fromString(
        '{"id":"u-9","name":"Ana Souza","email":"ana@teste.com","role":"RESIDENT","active":true}',
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      ));
      await tester.pumpAndSettle();
      expect(adapter.callsTo('POST /users'), 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('falha ao vincular a tag depois de criar o usuário', () {
    RoutedAdapter tagFails() => api(extra: {
          'POST /users/u-9/tags': apiError(409, 'TAG_CONFLICT', 'Tag de Fulano'),
        });

    Future<void> confirmWithTag(WidgetTester tester, RoutedAdapter adapter) async {
      await startWizard(tester, adapter, nfc: FakeNfcService(script: ['04A32F1B']));
      await goToReview(tester, readTag: true);
      await next(tester, 'Confirmar cadastro');
    }

    testWidgets('o usuário continua criado e o aviso não revela o dono da tag', (tester) async {
      final adapter = tagFails();
      await confirmWithTag(tester, adapter);

      expect(adapter.callsTo('POST /users'), 1);
      expect(find.text('Usuário cadastrado'), findsOneWidget);
      expect(find.textContaining('Esta tag já está cadastrada.'), findsOneWidget);
      expect(find.textContaining('Fulano'), findsNothing);
      expect(find.textContaining('pela edição do usuário'), findsOneWidget);
    });

    testWidgets('"Fechar" volta à lista, já atualizada', (tester) async {
      final adapter = tagFails();
      await confirmWithTag(tester, adapter);
      final listCalls = adapter.callsTo('GET /users');

      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NewUserWizardScreen), findsNothing);
      expect(adapter.callsTo('GET /users'), greaterThanOrEqualTo(listCalls));
    });

    testWidgets('"Abrir cadastro" leva à edição do usuário criado', (tester) async {
      final adapter = tagFails();
      await confirmWithTag(tester, adapter);

      await tester.tap(find.widgetWithText(FilledButton, 'Abrir cadastro'));
      await tester.pumpAndSettle();

      expect(find.byType(UserFormScreen), findsOneWidget);
      expect(find.text('Editar usuário'), findsOneWidget);
      expect(adapter.callsTo('GET /users/u-9'), 1);
    });
  });
}
