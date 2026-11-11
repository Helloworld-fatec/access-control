import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Armazenamento chave/valor para segredos (token, perfil da sessão).
///
/// Existe como contrato para que os testes usem uma versão em memória, sem
/// depender do Keystore do Android.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementação real, apoiada no Keystore do Android (`flutter_secure_storage`).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      // A chave do Keystore deixou de existir (aparelho restaurado, dados
      // corrompidos): o conteúdo ficou ilegível. Descartamos tudo e o usuário
      // entra de novo, em vez de o app falhar sempre ao abrir.
      await _wipe();
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> _wipe() async {
    try {
      await _storage.deleteAll();
    } on PlatformException {
      // Sem o que fazer: a leitura já devolve "vazio".
    }
  }
}

/// Armazenamento seguro do app. Os testes sobrescrevem com uma versão em memória.
final secureStoreProvider = Provider<SecureKeyValueStore>(
  (ref) => FlutterSecureKeyValueStore(),
);
