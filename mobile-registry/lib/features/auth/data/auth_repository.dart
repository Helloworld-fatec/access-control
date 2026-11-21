import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/interceptors/error_interceptor.dart';
import '../../../core/network/interceptors/request_interceptors.dart';
import 'auth_user.dart';

/// Login do administrador. Fala com o backend só pelo cliente HTTP único.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  static const String wrongCredentialsMessage = 'E-mail ou senha incorretos.';
  static const String accessDeniedMessage =
      'Acesso negado. Este aplicativo é exclusivo para administradores.';
  static const String loginNotFoundMessage =
      'Não encontramos o serviço de login neste servidor. '
      'Confira o endereço informado no login.';
  static const String invalidDataMessage =
      'Confira o e-mail e a senha informados.';
  static const String unexpectedResponseMessage =
      'O servidor respondeu algo inesperado. Tente novamente.';

  /// Valida o perfil retornado por `POST /login` antes de abrir a sessão.
  Future<(AuthUser, String)> login({
    required String email,
    required String password,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
        options: Options(
          extra: {
            // Ainda não existe token; e um 401 aqui é "senha errada", não
            // "sessão expirada".
            AuthInterceptor.skipAuthKey: true,
            ErrorInterceptor.skipSessionExpiredKey: true,
          },
        ),
      );
    } catch (e) {
      throw _forLoginScreen(ApiException.from(e));
    }

    final String token;
    final AuthUser user;
    try {
      final body = response.data;
      if (body is! Map) throw const FormatException();
      final rawToken = body['accessToken'];
      final rawUser = body['user'];
      if (rawToken is! String || rawToken.isEmpty || rawUser is! Map) {
        throw const FormatException();
      }
      token = rawToken;
      user = AuthUser.fromJson(Map<String, dynamic>.from(rawUser));
    } on FormatException {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: unexpectedResponseMessage,
      );
    }

    if (!user.isAdmin) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: accessDeniedMessage,
        statusCode: 403,
        code: 'FORBIDDEN',
      );
    }

    return (user, token);
  }

  /// Troca as mensagens genéricas por frases que fazem sentido na tela de login.
  ApiException _forLoginScreen(ApiException e) {
    String? message;
    switch (e.kind) {
      case ApiErrorKind.unauthorized:
        message = wrongCredentialsMessage;
      case ApiErrorKind.forbidden:
        message = accessDeniedMessage;
      case ApiErrorKind.notFound:
        message = loginNotFoundMessage;
      case ApiErrorKind.validation:
        message = invalidDataMessage;
      case ApiErrorKind.network:
      case ApiErrorKind.timeout:
      case ApiErrorKind.conflict:
      case ApiErrorKind.server:
      case ApiErrorKind.cancelled:
      case ApiErrorKind.unknown:
        break;
    }
    if (message == null) return e;
    return ApiException(
      kind: e.kind,
      message: message,
      statusCode: e.statusCode,
      code: e.code,
      details: e.details,
    );
  }
}
