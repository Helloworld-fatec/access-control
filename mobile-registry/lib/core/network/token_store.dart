import '../storage/secure_store.dart';

/// Contrato de armazenamento do token de acesso.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Token guardado no armazenamento seguro do aparelho (Keystore do Android).
/// Nunca vai para `shared_preferences`.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._store);

  /// Chave do token. A sessão (US-04) lê a mesma chave.
  static const String tokenKey = 'auth.token';

  final SecureKeyValueStore _store;

  @override
  Future<String?> read() => _store.read(tokenKey);

  @override
  Future<void> write(String token) => _store.write(tokenKey, token);

  @override
  Future<void> clear() => _store.delete(tokenKey);
}

/// Versão em memória (some ao fechar o app). Útil só em ferramentas e testes.
class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
