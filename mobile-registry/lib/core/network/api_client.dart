import 'package:dio/dio.dart';

import 'interceptors/error_interceptor.dart';
import 'interceptors/request_interceptors.dart';
import 'interceptors/retry_interceptor.dart';

/// Cria o cliente HTTP do app. É a ÚNICA porta de saída para o backend (RP05).
///
/// Ordem dos interceptadores: URL base → token → retry → padronização de erro.
Dio createApiClient({
  required String Function() baseUrl,
  Future<String?> Function()? readToken,
  void Function()? onUnauthorized,
  int maxRetries = 3,
  Duration Function(int attempt)? retryDelay,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.addAll([
    BaseUrlInterceptor(baseUrl),
    AuthInterceptor(readToken),
    RetryInterceptor(dio: dio, maxRetries: maxRetries, delay: retryDelay),
    ErrorInterceptor(onUnauthorized: onUnauthorized),
  ]);
  return dio;
}
