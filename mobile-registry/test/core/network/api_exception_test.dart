import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_exception.dart';

DioException badResponse(int status, [Object? body]) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

Map<String, Object> envelope(String code, String message, [Object? details]) => {
      'error': {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
    };

void main() {
  group('interpretação das respostas do backend', () {
    test('401 vira "sessão terminou"', () {
      final e = ApiException.fromDio(
        badResponse(401, envelope('UNAUTHORIZED', 'Token inválido')),
      );
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.message, ApiException.unauthorizedMessage);
    });

    test('403 vira falta de permissão', () {
      final e = ApiException.fromDio(badResponse(403));
      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.message, ApiException.forbiddenMessage);
    });

    test('404 usa a mensagem do servidor quando existe', () {
      final e = ApiException.fromDio(
        badResponse(404, envelope('NOT_FOUND', 'Registro não encontrado')),
      );
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, 'Registro não encontrado');
      expect(e.code, 'NOT_FOUND');
    });

    test('409 (conflito) usa a mensagem do servidor', () {
      final e = ApiException.fromDio(
        badResponse(409, envelope('CONFLICT', 'Já existe um registro com esses dados')),
      );
      expect(e.kind, ApiErrorKind.conflict);
      expect(e.message, 'Já existe um registro com esses dados');
    });

    test('409 sem corpo usa a frase padrão', () {
      final e = ApiException.fromDio(badResponse(409));
      expect(e.message, ApiException.conflictMessage);
    });

    test('400 de validação expõe os erros por campo', () {
      final e = ApiException.fromDio(
        badResponse(
          400,
          envelope('VALIDATION_ERROR', 'Dados inválidos', [
            {'path': 'name', 'message': 'Obrigatório'},
            {'path': 'document', 'message': 'Documento inválido'},
          ]),
        ),
      );
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, ApiException.validationMessage);
      expect(e.fieldErrors, {
        'name': 'Obrigatório',
        'document': 'Documento inválido',
      });
    });

    test('413 informa arquivo grande', () {
      final e = ApiException.fromDio(
        badResponse(413, envelope('FILE_TOO_LARGE', 'Arquivo maior que o limite permitido')),
      );
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, 'Arquivo maior que o limite permitido');
    });

    test('500 nunca vaza texto técnico do servidor', () {
      final e = ApiException.fromDio(
        badResponse(500, envelope('INTERNAL_ERROR', 'stack trace aqui')),
      );
      expect(e.kind, ApiErrorKind.server);
      expect(e.message, ApiException.serverMessage);
    });

    test('corpo que não é JSON do padrão não quebra', () {
      final e = ApiException.fromDio(badResponse(502, '<html>Bad Gateway</html>'));
      expect(e.kind, ApiErrorKind.server);
      expect(e.statusCode, 502);
    });
  });

  group('falhas de rede', () {
    DioException of(DioExceptionType t, {Object? error}) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: t,
          error: error,
        );

    test('timeouts', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(ApiException.fromDio(of(t)).kind, ApiErrorKind.timeout);
      }
    });

    test('erro de conexão e SocketException', () {
      expect(
        ApiException.fromDio(of(DioExceptionType.connectionError)).kind,
        ApiErrorKind.network,
      );
      expect(
        ApiException.fromDio(
          of(DioExceptionType.unknown, error: const SocketException('x')),
        ).kind,
        ApiErrorKind.network,
      );
    });

    test('cancelamento e desconhecido', () {
      expect(ApiException.fromDio(of(DioExceptionType.cancel)).kind, ApiErrorKind.cancelled);
      expect(ApiException.fromDio(of(DioExceptionType.unknown)).kind, ApiErrorKind.unknown);
    });
  });

  group('ApiException.from / userMessageFor', () {
    test('reaproveita o ApiException embutido no DioException', () {
      const inner = ApiException(kind: ApiErrorKind.conflict, message: 'ok');
      final dio = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: inner,
      );
      expect(ApiException.from(dio), same(inner));
    });

    test('erro qualquer vira mensagem genérica', () {
      expect(userMessageFor(StateError('boom')), ApiException.unknownMessage);
    });
  });
}
