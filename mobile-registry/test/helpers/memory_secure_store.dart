import 'package:mobile_registry/core/storage/secure_store.dart';

/// Armazenamento seguro em memória, para testes.
class MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  /// Faz as próximas gravações falharem (simula Keystore com problema).
  bool failOnWrite = false;

  /// Chaves cuja exclusão falha (simula erro ao apagar).
  final Set<String> failDeleteFor = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    if (failOnWrite) throw StateError('falha simulada ao gravar');
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeleteFor.contains(key)) {
      throw StateError('falha simulada ao apagar $key');
    }
    data.remove(key);
  }
}
