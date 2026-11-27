import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/routed_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

void main() {
  Future<void> start(
    WidgetTester tester,
    RoutedAdapter adapter, {
    Future<Uint8List?> Function()? capturePhoto,
  }) async {
    final env = await buildTestEnv(
      tester,
      signedInAs: testAdmin,
      adapter: adapter,
      logicalSize: tallScreen,
      capturePhoto: capturePhoto ??
          () async => File('../face-recognition/tests/astronaut.jpg')
              .readAsBytesSync(),
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('cria o usuário e permite vincular a tag pelo UID', (tester) async {
    var created = false;
    var linked = false;
    final adapter = RoutedAdapter({
      'GET /users': (options) => usersPage([if (created) userJson()])(options),
      'POST /users': (options) {
        created = true;
        return FakeAdapter.json(201, userJson())(options);
      },
      'GET /users/u-1': (options) =>
          FakeAdapter.json(200, detailJson(tags: [if (linked) tagJson()]))(options),
      'POST /users/u-1/tags': (options) {
        linked = true;
        return FakeAdapter.json(201, tagJson())(options);
      },
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
    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
    expect(find.text('Salvar usuário'), findsNothing);

    await tapVisible(tester, find.text('Maria Silva'));
    await tester.ensureVisible(field('UID da tag NFC'));
    await tester.enterText(field('UID da tag NFC'), '04:a3:2f:1b');
    await tapVisible(tester, find.text('Vincular tag NFC'));
    expect(adapter.callsTo('POST /users'), 1);
    expect(adapter.requests.singleWhere((req) => req.path == '/users/u-1/tags').data,
        {'uid': '04A32F1B'});
    expect(find.text('04A32F1B'), findsOneWidget);
    expect(find.text('Tag 04A32F1B vinculada a este perfil.'), findsOneWidget);

    Navigator.of(tester.element(find.text('Salvar usuário'))).pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Maria Silva'));
    expect(find.text('04A32F1B'), findsOneWidget);
    final uid = field('UID da tag NFC');
    await tester.ensureVisible(uid);
    await tester.enterText(uid, '04A32F1B');
    await tapVisible(tester, find.text('Vincular tag NFC'));
    expect(find.textContaining('vinculada a este perfil'), findsOneWidget);
    expect(adapter.callsTo('POST /users/u-1/tags'), 1);

    await tester.enterText(uid, '04A3');
    await tapVisible(tester, find.text('Vincular tag NFC'));
    expect(find.textContaining('UID hexadecimal de 4, 7 ou 10 bytes'), findsOneWidget);
    expect(adapter.callsTo('POST /users/u-1/tags'), 1);

    adapter.routes['POST /users/u-1/tags'] =
        apiError(409, 'TAG_CONFLICT', 'Esta tag já está cadastrada');
    await tester.enterText(uid, 'AA:BB:CC:DD');
    await tapVisible(tester, find.text('Vincular tag NFC'));
    expect(find.textContaining('Este UID já foi cadastrado'), findsOneWidget);
    expect(find.text('AABBCCDD'), findsNothing);
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
    await tapVisible(tester, find.text('Usar esta foto'));
    await tapVisible(tester, find.text('Salvar usuário'));
    expect(adapter.callsTo('POST /users/u-1/face'), 0);

    await tapVisible(
        tester, find.text('O usuário consentiu com o cadastro facial'));
    await tapVisible(tester, find.text('Salvar usuário'));
    final form = adapter.requests
        .singleWhere((request) => request.path == '/users/u-1/face')
        .data as FormData;
    expect(Map.fromEntries(form.fields), {'consent': 'true'});
    expect(form.files.single.key, 'photo');
    expect(form.files.single.value.contentType.toString(), 'image/jpeg');
    expect(find.textContaining('Nenhum rosto'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Editar usuário'), findsOneWidget);
    expect(find.text('Voltar à lista'), findsOneWidget);

    adapter.routes['POST /users/u-1/face'] =
        FakeAdapter.json(201, {'hasFace': true, 'hasPhoto': true});
    await tapVisible(tester, find.text('Tentar foto novamente'));
    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
    expect(find.text('Dados do usuário salvos.'), findsOneWidget);
    expect(adapter.callsTo('POST /users/u-1/face'), 2);
    expect(adapter.callsTo('PUT /users/u-1'), 0);
  });

  testWidgets('revisa a nova foto e mantém a atual se cancelar a troca',
      (tester) async {
    final bytes = File('../face-recognition/tests/astronaut.jpg').readAsBytesSync();
    var captures = 0;
    final adapter = RoutedAdapter({
      'GET /users': usersPage([userJson()]),
      'GET /users/u-1': FakeAdapter.json(200, detailJson(hasPhoto: true)),
      'GET /users/u-1/photo': (_) async => ResponseBody.fromBytes(
        bytes,
        200,
        headers: {Headers.contentTypeHeader: ['image/jpeg']},
      ),
    });
    await start(tester, adapter, capturePhoto: () async {
      if (++captures == 3) throw PlatformException(code: 'camera_access_denied');
      return bytes;
    });
    await tapVisible(tester, find.text('Maria Silva'));
    final change = find.text('Trocar foto');
    await tapVisible(tester, change);
    expect(find.text('Prévia da foto'), findsOneWidget);
    await tapVisible(tester, find.text('Tirar novamente'));
    expect(captures, 2);
    await tapVisible(tester, find.text('Cancelar'));
    expect(find.bySemanticsLabel('Foto cadastrada'), findsOneWidget);
    expect(find.text('Nova foto · pendente de envio'), findsNothing);

    await tapVisible(tester, change);
    expect(find.textContaining('Permita o acesso à câmera'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto cadastrada'), findsOneWidget);
    expect(adapter.callsTo('POST /users/u-1/face'), 0);
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
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
    expect(adapter.callsTo('GET /users/u-2/photo'), 0);
    await tapVisible(tester, find.text('Maria Silva'));
    expect(find.bySemanticsLabel('Foto cadastrada'), findsOneWidget);
    final requests = adapter.requests.where((request) => request.path.endsWith('/photo'));
    expect(requests, hasLength(2));
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer tok-123'), isTrue);
  });

  testWidgets('salva edição, retorna à lista e permite reabrir para exclusão',
      (tester) async {
    var name = 'Maria Silva';
    final adapter = RoutedAdapter({
      'GET /users': (options) => usersPage([userJson(name: name)])(options),
      'GET /users/u-1': (options) =>
          FakeAdapter.json(200, detailJson(name: name))(options),
      'PUT /users/u-1': (options) {
        name = 'Maria Costa';
        return FakeAdapter.json(200, userJson(name: name))(options);
      },
      'DELETE /users/u-1': FakeAdapter.json(204, {}),
    });
    await start(tester, adapter);
    await tapVisible(tester, find.text('Maria Silva'));
    await tester.enterText(field('Nome completo'), 'Maria Costa');
    await tapVisible(tester, find.text('Salvar usuário'));
    expect(adapter.callsTo('PUT /users/u-1'), 1);
    expect(adapter.callsTo('POST /users/u-1/nfc-enrollments'), 0);
    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
    expect(find.text('Dados do usuário salvos.'), findsOneWidget);
    await tapVisible(tester, find.text('Maria Costa'));
    await tapVisible(tester, find.text('Excluir usuário'));
    await tapVisible(tester, find.text('Cancelar'));
    expect(adapter.callsTo('DELETE /users/u-1'), 0);
    await tapVisible(tester, find.text('Excluir usuário'));
    await tapVisible(tester, find.text('Excluir'));
    expect(adapter.callsTo('DELETE /users/u-1'), 1);
    expect(find.widgetWithText(AppBar, 'Usuários'), findsOneWidget);
  });
}
