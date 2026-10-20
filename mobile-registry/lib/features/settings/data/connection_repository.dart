import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';

/// Verifica se o backend responde, usando o cliente HTTP único.
class ConnectionRepository {
  ConnectionRepository(this._dio);

  final Dio _dio;

  /// `GET /api/health`. Lança [ApiException] com mensagem simples em caso de falha.
  Future<void> check() async {
    try {
      await _dio.get<dynamic>('/health');
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final connectionRepositoryProvider = Provider<ConnectionRepository>(
  (ref) => ConnectionRepository(ref.watch(dioProvider)),
);
