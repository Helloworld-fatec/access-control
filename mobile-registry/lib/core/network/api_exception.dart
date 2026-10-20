import 'dart:io';

import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  cancelled,
  unknown,
}

/// Erro padronizado do app. A [message] está sempre em linguagem simples e
/// pode ser exibida direto ao usuário.
///
/// O backend responde erros no formato único:
/// `{ "error": { "code": "...", "message": "...", "details": ... } }`.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// Código de máquina do backend (ex.: `CONFLICT`, `VALIDATION_ERROR`).
  final String? code;
  final Object? details;

  static const String networkMessage =
      'Não foi possível conectar ao servidor. Verifique o Wi-Fi e o endereço configurado.';
  static const String timeoutMessage =
      'O servidor demorou para responder. Tente novamente.';
  static const String unauthorizedMessage =
      'Sua sessão terminou. Entre novamente.';
  static const String forbiddenMessage =
      'Você não tem permissão para fazer isso.';
  static const String notFoundMessage = 'Não encontramos o que você procurou.';
  static const String conflictMessage = 'Esses dados já estão cadastrados.';
  static const String validationMessage = 'Confira os dados informados.';
  static const String serverMessage =
      'O servidor está com problemas. Tente de novo em instantes.';
  static const String unknownMessage =
      'Algo deu errado. Tente novamente.';

  /// Erros de campo vindos de `details: [{ path, message }]`.
  Map<String, String> get fieldErrors {
    final d = details;
    if (d is! List) return const {};
    final result = <String, String>{};
    for (final item in d) {
      if (item is Map && item['path'] != null && item['message'] != null) {
        result['${item['path']}'] = '${item['message']}';
      }
    }
    return result;
  }

  /// Converte qualquer erro capturado em [ApiException].
  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner;
      return fromDio(error);
    }
    return const ApiException(
      kind: ApiErrorKind.unknown,
      message: unknownMessage,
    );
  }

 static ApiException fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: timeoutMessage,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: networkMessage,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'A operação foi cancelada.',
        );
      case DioExceptionType.badResponse:
        return fromResponse(e.response);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const ApiException(
            kind: ApiErrorKind.network,
            message: networkMessage,
          );
        }
        return const ApiException(
          kind: ApiErrorKind.unknown,
          message: unknownMessage,
        );
    }
  }

  static ApiException fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;

    String? serverCode;
    String? serverText;
    Object? details;
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      serverCode = err['code']?.toString();
      serverText = err['message']?.toString();
      details = err['details'];
    }
    final hasText = serverText != null && serverText.trim().isNotEmpty;

    ApiException make(ApiErrorKind kind, String fallback,
        {bool useServerText = false}) {
      return ApiException(
        kind: kind,
        message: useServerText && hasText ? serverText! : fallback,
        statusCode: status,
        code: serverCode,
        details: details,
      );
    }

    if (status == 401) return make(ApiErrorKind.unauthorized, unauthorizedMessage);
    if (status == 403) return make(ApiErrorKind.forbidden, forbiddenMessage);
    if (status == 404) {
      return make(ApiErrorKind.notFound, notFoundMessage, useServerText: true);
    }
    if (status == 409) {
      return make(ApiErrorKind.conflict, conflictMessage, useServerText: true);
    }
    if (status == 413) {
      return make(ApiErrorKind.validation, 'O arquivo é maior que o permitido.',
          useServerText: true);
    }
    if (status == 400 || status == 422) {
      // "Dados inválidos" é genérico demais: preferimos a frase padrão do app.
      return make(ApiErrorKind.validation, validationMessage);
    }
    if (status >= 500) return make(ApiErrorKind.server, serverMessage);
    return make(ApiErrorKind.unknown, unknownMessage);
  }

  @override
  String toString() => 'ApiException($kind, status=$statusCode, code=$code)';
}

/// Atalho para telas: mensagem amigável de qualquer erro capturado.
String userMessageFor(Object error) => ApiException.from(error).message;
