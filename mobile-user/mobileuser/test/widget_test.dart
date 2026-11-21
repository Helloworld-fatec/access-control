import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobileuser/app/app.dart';
import 'package:mobileuser/core/session/session_controller.dart';
import 'package:mobileuser/core/session/session_scope.dart';
import 'package:mobileuser/features/home/home_page.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('abre a tela de login sem uma sessão', (tester) async {
    await tester.pumpWidget(const MobileUserApp());
    await tester.pumpAndSettle();

    expect(find.text('Controle de Acesso'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
  });

  testWidgets('carrega a própria foto e limpa a imagem ao trocar de sessão', (
    tester,
  ) async {
    final bytes = File('../../face-recognition/tests/astronaut.jpg')
        .readAsBytesSync();
    final newPhoto = Completer<http.Response>();
    final photoTokens = <String?>[];
    final session = SessionController(
      client: MockClient((request) async {
        if (request.url.path == '/api/login') {
          final email = (jsonDecode(request.body) as Map)['email'] as String;
          return http.Response(
            jsonEncode({
              'accessToken': email,
              'user': {'name': email},
            }),
            200,
          );
        }
        expect(request.url.path, '/api/users/me/photo');
        expect(request.headers['accept'], 'image/jpeg');
        final token = request.headers['authorization'];
        photoTokens.add(token);
        if (token == 'Bearer ana@teste.com') {
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        return newPhoto.future;
      }),
    );
    addTearDown(session.dispose);
    await session.login('http://localhost:3000', 'ana@teste.com', 'senha');
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto do perfil'), findsOneWidget);
    expect(photoTokens, ['Bearer ana@teste.com']);

    await session.login('http://localhost:3000', 'bia@teste.com', 'senha');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Foto do perfil'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    newPhoto.complete(http.Response('', 404));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(photoTokens, ['Bearer ana@teste.com', 'Bearer bia@teste.com']);
  });
}
