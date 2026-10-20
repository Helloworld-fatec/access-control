import 'package:dio/dio.dart';

import '../api_exception.dart';

/// Último interceptor: padroniza todo erro em [ApiException] e avisa o app
/// quando o token não vale mais (401).
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({this.onUnauthorized});

  /// Em rotas como o login (US-04), passe
  /// `Options(extra: {ErrorInterceptor.skipSessionExpiredKey: true})`
  /// para que um 401 de "senha errada" não seja tratado como sessão expirada.
  static const String skipSessionExpiredKey = 'skipSessionExpired';

  final void Function()? onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Já padronizado (ex.: erro vindo de uma nova tentativa do retry).
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }

    final exception = ApiException.fromDio(err);
    if (exception.kind == ApiErrorKind.unauthorized &&
        err.requestOptions.extra[skipSessionExpiredKey] != true) {
      onUnauthorized?.call();
    }
    handler.next(err.copyWith(error: exception, message: exception.message));
  }
}
