import 'dart:convert';

import '../../../core/network/token_store.dart';
import '../../../core/storage/secure_store.dart';
import 'auth_user.dart';

/// Sessão do administrador no armazenamento seguro: token + perfil.
///
/// Os dois são gravados e apagados juntos. Se um existir sem o outro, a
/// sessão é considerada inválida e é limpa.
class SessionStorage {
  SessionStorage({required SecureKeyValueStore store, required TokenStore tokens})
      : _store = store,
        _tokens = tokens;

  static const String userKey = 'auth.user';

  final SecureKeyValueStore _store;
  final TokenStore _tokens;

  Future<void> save({required String token, required AuthUser user}) async {
    await _tokens.write(token);
    await _store.write(userKey, jsonEncode(user.toJson()));
  }

  /// Devolve o administrador da sessão guardada, ou `null` se não houver
  /// sessão utilizável (nesse caso, qualquer resto é apagado, sem lançar erro).
  Future<AuthUser?> restore() async {
    final token = await _tokens.read();
    final raw = await _store.read(userKey);

    if (token == null || token.isEmpty || raw == null) {
      if (token != null || raw != null) await _clearQuietly();
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final user = AuthUser.fromJson(decoded);
      if (!user.isAdmin) {
        await _clearQuietly();
        return null;
      }
      return user;
    } on FormatException {
      await _clearQuietly();
      return null;
    }
  }

  /// Apaga token e perfil. Tenta apagar os dois mesmo que um falhe, e só
  /// depois repassa o primeiro erro: nunca sobra um segredo por causa de outro.
  Future<void> clear() async {
    Object? failure;
    StackTrace? failureTrace;

    try {
      await _tokens.clear();
    } catch (e, s) {
      failure = e;
      failureTrace = s;
    }
    try {
      await _store.delete(userKey);
    } catch (e, s) {
      failure ??= e;
      failureTrace ??= s;
    }

    if (failure != null) Error.throwWithStackTrace(failure, failureTrace!);
  }

  /// Limpeza usada ao abrir o app: se até ela falhar, seguimos sem sessão em
  /// vez de impedir o app de abrir.
  Future<void> _clearQuietly() async {
    try {
      await clear();
    } catch (_) {
      // Sem sessão utilizável de qualquer forma.
    }
  }
}
