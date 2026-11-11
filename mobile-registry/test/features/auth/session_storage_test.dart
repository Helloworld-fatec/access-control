import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/token_store.dart';
import 'package:mobile_registry/features/auth/data/session_storage.dart';

import '../../helpers/memory_secure_store.dart';
import '../../helpers/test_app.dart';

void main() {
  late MemorySecureStore store;
  late SecureTokenStore tokens;
  late SessionStorage session;

  setUp(() {
    store = MemorySecureStore();
    tokens = SecureTokenStore(store);
    session = SessionStorage(store: store, tokens: tokens);
  });

  test('o token usa a chave auth.token do armazenamento seguro', () async {
    await tokens.write('abc');
    expect(store.data[SecureTokenStore.tokenKey], 'abc');
    expect(SecureTokenStore.tokenKey, 'auth.token');
    expect(await tokens.read(), 'abc');
    await tokens.clear();
    expect(await tokens.read(), isNull);
  });

  test('guarda e restaura token e administrador', () async {
    await session.save(token: 'tok', user: testAdmin);
    expect(await tokens.read(), 'tok');
    expect(await session.restore(), testAdmin);
  });

  test('sem nada guardado, não há sessão', () async {
    expect(await session.restore(), isNull);
  });

  test('token sem perfil: sessão inválida e restos apagados', () async {
    await tokens.write('tok');
    expect(await session.restore(), isNull);
    expect(store.data, isEmpty);
  });

  test('perfil sem token: sessão inválida e restos apagados', () async {
    store.data[SessionStorage.userKey] = jsonEncode(testAdmin.toJson());
    expect(await session.restore(), isNull);
    expect(store.data, isEmpty);
  });

  test('perfil corrompido: sessão inválida e restos apagados', () async {
    await tokens.write('tok');
    store.data[SessionStorage.userKey] = '{isso não é json';
    expect(await session.restore(), isNull);
    expect(store.data, isEmpty);
  });

  test('perfil incompleto: sessão inválida e restos apagados', () async {
    await tokens.write('tok');
    store.data[SessionStorage.userKey] = jsonEncode({'id': 'u1'});
    expect(await session.restore(), isNull);
    expect(store.data, isEmpty);
  });

  test('perfil que não é administrador nunca é restaurado', () async {
    await tokens.write('tok');
    store.data[SessionStorage.userKey] = jsonEncode({
      ...testAdmin.toJson(),
      'role': 'RESIDENT',
    });
    expect(await session.restore(), isNull);
    expect(store.data, isEmpty);
  });

  test('clear apaga token e perfil juntos', () async {
    await session.save(token: 'tok', user: testAdmin);
    await session.clear();
    expect(store.data, isEmpty);
  });

  test('clear tenta apagar tudo mesmo se a primeira exclusão falhar', () async {
    await session.save(token: 'tok', user: testAdmin);
    store.failDeleteFor.add(SecureTokenStore.tokenKey);

    await expectLater(session.clear(), throwsStateError);

    // O perfil foi apagado apesar da falha ao apagar o token.
    expect(store.data.containsKey(SessionStorage.userKey), isFalse);
  });

  test('clear apaga o token mesmo se a exclusão do perfil falhar', () async {
    await session.save(token: 'tok', user: testAdmin);
    store.failDeleteFor.add(SessionStorage.userKey);

    await expectLater(session.clear(), throwsStateError);

    expect(store.data.containsKey(SecureTokenStore.tokenKey), isFalse);
  });

  test('restore não lança erro nem impede o app de abrir se a limpeza falhar', () async {
    await tokens.write('tok'); // token sem perfil: restore tenta limpar
    store.failDeleteFor.add(SecureTokenStore.tokenKey);

    expect(await session.restore(), isNull);
  });
}
