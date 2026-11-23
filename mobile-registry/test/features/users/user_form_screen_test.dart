import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

void main() {
  Future<void> start(WidgetTester tester, RoutedAdapter adapter) async {
    final env = await buildTestEnv(
      tester,
      signedInAs: testAdmin,
      adapter: adapter,
      logicalSize: tallScreen,
      capturePhoto: () async =>
          File('../face-recognition/tests/astronaut.jpg').readAsBytesSync(),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('cria o usuário e permite vincular a tag pelo UID', (tester) async {
    final adapter = RoutedAdapter({
      'GET /users': usersPage([]),
      'POST /users': FakeAdapter.json(201, userJson()),
      'POST /users/u-1/tags': FakeAdapter.json(201, tagJson()),
    });
    await start(tester, adapter);
    await tapVisible(tester, find.text('Novo usuário'));
    await tester.enterText(field('Nome completo'), 'Maria Silva');
    await tester.enterText(field('E-mail'), 'maria@teste.com');
    await tester.enterText(field('Senha'), 'senha123');
    await tapVisible(tester, find.text('Condômino').last);
    await tapVisible(tester, find.text('Salvar usuário'));

    expect(adapter.callsTo('POST /users/u-1/tags'), 0);
    expect(find.text('Usuário criado.'), findsOneWidget);

    await tester.ensureVisible(field('UID da tag NFC'));
    await tester.enterText(field('UID da tag NFC'), '04:a3:2f:1b');
    await tapVisible(tester, find.text('Vincular tag NFC'));
    expect(adapter.callsTo('POST /users'), 1);
    expect(adapter.requests.singleWhere((req) => req.path == '/users/u-1/tags').data,
        {'uid': '04A32F1B'});
    expect(find.text('04A32F1B'), findsOneWidget);
  });

  testWidgets('envia foto consentida como JPEG e permite retentar só a foto',
      (tester) async {
    final adapter = RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'GET /users/u-1': FakeAdapter.json(200, detailJson()),
      'POST /users/u-1/face': apiError(422, 'NO_FACE', 'Sem rosto'),
    });
    await start(tester, adapter);
    await tapVisible(tester, find.text('Maria Silva'));
    await tapVisible(tester, find.text('Tirar foto'));
    await tapVisible(tester, find.text('Salvar usuário'));
    expect(adapter.callsTo('POST /users/u-1/face'), 0);

    await tapVisible(
        tester, find.text('O usuário consentiu com o cadastro facial'));
    await tapVisible(tester, find.text('Salvar usuário'));
    final form = adapter.requests.last.data as FormData;
    expect(Map.fromEntries(form.fields), {'consent': 'true'});
    expect(form.files.single.key, 'photo');
    expect(form.files.single.value.contentType.toString(), 'image/jpeg');
    expect(find.textContaining('Nenhum rosto'), findsOneWidget);

    adapter.routes['POST /users/u-1/face'] =
        FakeAdapter.json(201, {'hasFace': true, 'hasPhoto': true});
    await tapVisible(tester, find.text('Tentar foto novamente'));
    expect(find.text('Rosto cadastrado'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto cadastrada'), findsOneWidget);
    expect(adapter.callsTo('PUT /users/u-1'), 0);
  });

  testWidgets('carrega a foto autenticada no cartão e na edição', (tester) async {
    final bytes = File('../face-recognition/tests/astronaut.jpg').readAsBytesSync();
    final adapter = RoutedAdapter({
      'GET /users': usersPage([
        userJson(hasPhoto: true),
        userJson(id: 'u-2', name: 'Sem foto'),
      ]),
      'GET /users/u-1': FakeAdapter.json(200, detailJson(hasPhoto: true)),
      'GET /users/u-1/photo': (options) async => ResponseBody.fromBytes(
        bytes,
        200,
        headers: {Headers.contentTypeHeader: ['image/jpeg']},
      ),
    });
    await start(tester, adapter);
    expect(find.byType(Image), findsOneWidget);
    expect(adapter.callsTo('GET /users/u-2/photo'), 0);
    await tapVisible(tester, find.text('Maria Silva'));
    expect(find.bySemanticsLabel('Foto cadastrada'), findsOneWidget);
    final requests = adapter.requests.where((request) => request.path.endsWith('/photo'));
    expect(requests, hasLength(2));
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer tok-123'), isTrue);
  });

  testWidgets('salva edição e volta à lista após confirmar exclusão',
      (tester) async {
    final adapter = RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'GET /users/u-1': FakeAdapter.json(200, detailJson()),
      'PUT /users/u-1': FakeAdapter.json(200, userJson(name: 'Maria Costa')),
      'DELETE /users/u-1': FakeAdapter.json(204, {}),
    });
    await start(tester, adapter);
    await tapVisible(tester, find.text('Maria Silva'));
    await tester.enterText(field('Nome completo'), 'Maria Costa');
    await tapVisible(tester, find.text('Salvar usuário'));
    expect(adapter.callsTo('PUT /users/u-1'), 1);
    expect(adapter.callsTo('POST /users/u-1/nfc-enrollments'), 0);
    await tapVisible(tester, find.text('Excluir usuário'));
    await tapVisible(tester, find.text('Cancelar'));
    expect(adapter.callsTo('DELETE /users/u-1'), 0);
    await tapVisible(tester, find.text('Excluir usuário'));
    await tapVisible(tester, find.text('Excluir'));
    expect(adapter.callsTo('DELETE /users/u-1'), 1);
    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
  });
}
