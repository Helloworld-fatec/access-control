import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/app.dart';
import 'package:mobile_registry/features/auth/application/session_controller.dart';
import 'package:mobile_registry/features/auth/data/auth_user.dart';
import 'package:mobile_registry/features/users/data/face_camera.dart';

import 'fake_adapter.dart';

/// Administrador usado nos testes.
const testAdmin = AuthUser(
  id: 'u1',
  name: 'Ana Souza',
  email: 'admin@teste.com',
  role: 'ADMIN',
);

/// Resposta de `POST /login` de um administrador.
FakeHandler loginOk({String role = 'ADMIN', String token = 'tok-123'}) =>
    FakeAdapter.json(200, {
      'accessToken': token,
      'user': {
        'id': 'u1',
        'name': 'Ana Souza',
        'email': 'admin@teste.com',
        'role': role,
      },
    });

SessionController testSession({FakeAdapter? adapter, AuthUser? signedInAs}) {
  final session = SessionController(
    adapter: adapter ??
        FakeAdapter([
          FakeAdapter.json(200, {'status': 'ok'})
        ]),
    retryDelay: (_) => Duration.zero,
  );
  if (signedInAs != null) session.startSession(signedInAs, 'tok-123');
  addTearDown(session.dispose);
  return session;
}

class TestEnv {
  TestEnv(this.session, this.adapter, this.widget);

  final SessionController session;
  final FakeAdapter adapter;
  final Widget widget;
}

const Size tallScreen = Size(360, 3000);

Future<TestEnv> buildTestEnv(
  WidgetTester tester, {
  FakeAdapter? adapter,
  AuthUser? signedInAs,
  Size logicalSize = const Size(360, 800),
  FacePhotoCapture capturePhoto = captureFacePhoto,
}) async {
  tester.view.physicalSize =
      Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final fake = adapter ??
      FakeAdapter([
        FakeAdapter.json(200, {'status': 'ok'})
      ]);
  final session = testSession(adapter: fake, signedInAs: signedInAs);
  return TestEnv(session, fake,
      AccessRegistryApp(session: session, capturePhoto: capturePhoto));
}

/// Rola até o item e toca nele.
///
/// Antes de rolar, deixa terminar o que ficou agendado depois de um `enterText`:
/// o campo de texto manda a tela mostrar o cursor, o que desfaria a rolagem
/// e deixaria o botão fora da tela.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  // Listas só constroem o que está perto da área visível: se o item ainda não
  // existe, rola a lista até ele aparecer.
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
