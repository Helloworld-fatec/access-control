import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/interceptors/error_interceptor.dart';
import '../../../core/network/network_providers.dart';

/// Verifica se o backend responde, usando o cliente HTTP único.
class ConnectionRepository {
  ConnectionRepository(this._dio);

  final Dio _dio;

  /// `GET /api/health`. Lança [ApiException] com mensagem simples em caso de falha.
  ///
  /// Testar a conexão nunca encerra a sessão: mesmo que um dia o servidor
  /// responda 401 a esta rota, isso não significa que o token expirou.
  Future<void> check() async {
    try {
      await _dio.get<dynamic>(
        '/health',
        options: Options(extra: {ErrorInterceptor.skipSessionExpiredKey: true}),
      );
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(ref.watch(dioProvider)),
);
