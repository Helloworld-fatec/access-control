import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/settings_providers.dart';
import 'api_client.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());

/// Contador de eventos "sessão expirada" (401). A US-05 vai ouvir este
/// provider para limpar o token e levar o usuário ao login.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
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
    onUnauthorized: () => ref.read(sessionExpiredProvider.notifier).notify(),
    adapter: ref.watch(httpClientAdapterProvider),
    retryDelay: ref.watch(retryDelayProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});
