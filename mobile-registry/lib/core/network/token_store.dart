/// Contrato de armazenamento do token de acesso.
///
/// Nesta etapa só existe a versão em memória. Na US-04 ela será substituída
/// por uma implementação com `flutter_secure_storage` (nunca shared_preferences).
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
