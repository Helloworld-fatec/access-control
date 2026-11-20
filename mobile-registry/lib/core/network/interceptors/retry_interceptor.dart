import 'package:dio/dio.dart';

/// Repete automaticamente chamadas que falharam por instabilidade de rede
/// (RNF03), com espera crescente (0,5 s, 1 s, 2 s) e limite de tentativas.
///
/// Regras de segurança contra cadastro duplicado:
/// - GET/HEAD/PUT/DELETE: repete em timeout, erro de conexão e 502/503/504;
/// - POST/PATCH: repete só quando a requisição nem chegou ao servidor
///   (timeout de conexão ou erro de conexão), nunca após timeout de resposta.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    Duration Function(int attempt)? delay,
  }) : delay = delay ?? defaultDelay;

  static const String retryingKey = 'isRetrying';
  static const Set<String> _idempotent = {
    'GET',
    'HEAD',
    'PUT',
    'DELETE',
    'OPTIONS',
  };

  final Dio dio;
  final int maxRetries;
  final Duration Function(int attempt) delay;

  static Duration defaultDelay(int attempt) =>
      Duration(milliseconds: 500 * (1 << (attempt - 1)));

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (options.extra[retryingKey] == true || !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    var last = err;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      await Future<void>.delayed(delay(attempt));
      try {
        final response = await dio.fetch<dynamic>(_cloneForRetry(options));
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        last = e;
        if (!_isRetryable(e)) break;
      }
    }
    handler.next(last);
  }

  bool _isRetryable(DioException err) {
    final idempotent =
        _idempotent.contains(err.requestOptions.method.toUpperCase());
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return idempotent;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        return idempotent && (status == 502 || status == 503 || status == 504);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  RequestOptions _cloneForRetry(RequestOptions options) {
    final data = options.data;
    return options.copyWith(
      // FormData só pode ser enviado uma vez: precisa ser clonado.
      data: data is FormData ? data.clone() : data,
      extra: {...options.extra, retryingKey: true},
    );
  }
}
