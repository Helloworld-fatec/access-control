import 'package:dio/dio.dart';

import 'retry_interceptor.dart';

/// Aplica a URL base *atual* (configurável pelo usuário) a cada requisição.
class BaseUrlInterceptor extends Interceptor {
  BaseUrlInterceptor(this._baseUrl);

  final String Function() _baseUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[RetryInterceptor.retryingKey] != true) {
      options.baseUrl = _baseUrl();
    }
    handler.next(options);
  }
}

/// Anexa `Authorization: Bearer <token>` quando existe token.
/// Use `Options(extra: {AuthInterceptor.skipAuthKey: true})` em rotas públicas.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._readToken);

  static const String skipAuthKey = 'skipAuth';

  final Future<String?> Function()? _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // A retentativa conserva a origem e o Bearer da requisição original.
    if (options.extra[RetryInterceptor.retryingKey] != true &&
        options.extra[skipAuthKey] != true &&
        _readToken != null) {
      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
