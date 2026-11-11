import 'package:dio/dio.dart';

import '../api_exception.dart';

/// Último interceptor: padroniza todo erro em [ApiException] e avisa o app
/// quando o token não vale mais (401).
///
/// O aviso leva o token que a requisição enviou. Assim o app distingue um 401
/// da sessão atual de um 401 atrasado, de uma sessão que já foi encerrada.
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({this.onUnauthorized});

  /// Em rotas como o login (US-04), passe
  /// `Options(extra: {ErrorInterceptor.skipSessionExpiredKey: true})`
  /// para que um 401 de "senha errada" não seja tratado como sessão expirada.
  static const String skipSessionExpiredKey = 'skipSessionExpired';

  final void Function(String? sentToken)? onUnauthorized;

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
      onUnauthorized?.call(_bearerToken(err.requestOptions));
    }
    handler.next(err.copyWith(error: exception, message: exception.message));
  }

  /// Token enviado em `Authorization: Bearer <token>`, ou `null` se não havia.
  static String? _bearerToken(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is String && header.startsWith('Bearer ')) {
      return header.substring('Bearer '.length);
    }
    return null;
  }
}
