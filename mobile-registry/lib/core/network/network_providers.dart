import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/settings_providers.dart';
import '../storage/secure_store.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Token de acesso, guardado no armazenamento seguro (US-04).
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(ref.watch(secureStoreProvider)),
);

/// Evento "sessão expirada" (o backend respondeu 401 a uma chamada autenticada).
///
/// O estado é um contador que sobe a cada evento; [lastSentToken] guarda o
/// token que a requisição enviou. Quem trata o evento (`AuthNotifier`)
/// compara esse token com o atual para ignorar 401 atrasados.
class SessionExpiredNotifier extends Notifier<int> {
  String? lastSentToken;

  @override
  int build() => 0;

  void notify([String? sentToken]) {
    lastSentToken = sentToken;
    state++;
  }
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// Ganchos usados só em testes.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);
final retryDelayProvider =
    Provider<Duration Function(int attempt)?>((ref) => null);

/// Cliente HTTP único do app.
final dioProvider = Provider<Dio>((ref) {
  final dio = createApiClient(
    baseUrl: () => ref.read(settingsProvider).baseUrl,
    readToken: () => ref.read(tokenStoreProvider).read(),
    onUnauthorized: (sentToken) =>
        ref.read(sessionExpiredProvider.notifier).notify(sentToken),
    adapter: ref.watch(httpClientAdapterProvider),
    retryDelay: ref.watch(retryDelayProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});
