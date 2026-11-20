import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// No Riverpod 3 o tipo Override fica em misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/app.dart';
import 'package:mobile_registry/core/config/settings_providers.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/core/nfc/nfc_service.dart';
import 'package:mobile_registry/core/storage/secure_store.dart';
import 'package:mobile_registry/core/theme/app_theme.dart';
import 'package:mobile_registry/features/auth/application/auth_providers.dart';
import 'package:mobile_registry/features/auth/data/auth_user.dart';
import 'package:mobile_registry/features/auth/data/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_adapter.dart';
import 'fake_nfc_service.dart';
import 'memory_secure_store.dart';

/// Administrador usado nos testes.
const testAdmin = AuthUser(
  id: 'u1',
  name: 'Ana Souza',
  email: 'admin@teste.com',
  role: 'ADMIN',
);

/// Resposta de `POST /auth/login` de um administrador.
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

/// Deixa token e perfil no armazenamento seguro, como se o usuário já tivesse
/// feito login (use junto com `signedInAs: testAdmin`).
void seedSession(
  MemorySecureStore store, {
  String token = 'tok-123',
  AuthUser user = testAdmin,
}) {
  store.data['auth.token'] = token;
  store.data[SessionStorage.userKey] = jsonEncode(user.toJson());
}

class TestEnv {
  TestEnv(this.prefs, this.adapter, this.secureStore, this.nfc, this.widget);
  final SharedPreferences prefs;
  final FakeAdapter adapter;
  final MemorySecureStore secureStore;
  final FakeNfcService nfc;
  final Widget widget;
}

List<Override> testOverrides({
  required SharedPreferences prefs,
  required FakeAdapter adapter,
  required MemorySecureStore secureStore,
  required FakeNfcService nfc,
  AuthUser? signedInAs,
}) {
  return [
    nfcServiceProvider.overrideWithValue(nfc),
    sharedPreferencesProvider.overrideWithValue(prefs),
    httpClientAdapterProvider.overrideWithValue(adapter),
    retryDelayProvider.overrideWithValue((_) => Duration.zero),
    secureStoreProvider.overrideWithValue(secureStore),
    initialAuthUserProvider.overrideWithValue(signedInAs),
  ];
}

/// Container sem interface, para testes de lógica.
Future<ProviderContainer> buildContainer({
  FakeAdapter? adapter,
  MemorySecureStore? secureStore,
  AuthUser? signedInAs,
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: testOverrides(
      prefs: prefs,
      adapter: adapter ??
          FakeAdapter([
            FakeAdapter.json(200, {'status': 'ok'}),
          ]),
      secureStore: secureStore ?? MemorySecureStore(),
      nfc: FakeNfcService(),
      signedInAs: signedInAs,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

/// Tamanho de tela (em dp) para testes de listas longas.
///
/// Nos testes o texto usa a fonte "Ahem" (cada letra é um quadrado do tamanho
/// da fonte), bem mais larga que a fonte real: os textos quebram em muitas
/// linhas e um cartão da lista pode ocupar uma tela inteira. Com uma tela alta,
/// todos os itens são construídos e ficam visíveis, como no aparelho.
const Size tallScreen = Size(360, 3000);

/// Monta o app (ou apenas [home]) com armazenamento e rede falsos.
/// Por padrão ninguém está logado; use [signedInAs] para começar logado.
/// [logicalSize] é o tamanho da tela em dp (padrão: celular 360x800).
Future<TestEnv> buildTestEnv(
  WidgetTester tester, {
  Widget? home,
  FakeAdapter? adapter,
  MemorySecureStore? secureStore,
  FakeNfcService? nfc,
  AuthUser? signedInAs,
  Map<String, Object> initialPrefs = const {},
  Size logicalSize = const Size(360, 800),
}) async {
  tester.view.physicalSize =
      Size(logicalSize.width * 3, logicalSize.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final fake = adapter ??
      FakeAdapter([
        FakeAdapter.json(200, {'status': 'ok'}),
      ]);
  final store = secureStore ?? MemorySecureStore();
  final fakeNfc = nfc ?? FakeNfcService();

  final widget = ProviderScope(
    overrides: testOverrides(
      prefs: prefs,
      adapter: fake,
      secureStore: store,
      nfc: fakeNfc,
      signedInAs: signedInAs,
    ),
    child: home == null
        ? const AccessRegistryApp()
        : MaterialApp(theme: AppTheme.light(), home: home),
  );
  return TestEnv(prefs, fake, store, fakeNfc, widget);
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
