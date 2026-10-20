import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/network/api_client.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/interceptors/error_interceptor.dart';
import 'package:mobile_registry/core/network/interceptors/request_interceptors.dart';

import '../../helpers/fake_adapter.dart';

Dio client(
  FakeAdapter adapter, {
  String Function()? baseUrl,
  Future<String?> Function()? readToken,
  void Function()? onUnauthorized,
  int maxRetries = 3,
}) {
  return createApiClient(
    baseUrl: baseUrl ?? () => 'http://10.0.2.2:3000/api',
    readToken: readToken,
    onUnauthorized: onUnauthorized,
    maxRetries: maxRetries,
    retryDelay: (_) => Duration.zero,
    adapter: adapter,
  );
}

Future<ApiException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } catch (e) {
    return ApiException.from(e);
  }
  fail('A chamada deveria ter falhado');
}

void main() {
  group('retry', () {
    test('GET: tenta de novo após timeouts e acaba com sucesso', () async {
      final adapter = FakeAdapter([
        FakeAdapter.fail(DioExceptionType.connectionTimeout),
        FakeAdapter.fail(DioExceptionType.receiveTimeout),
        FakeAdapter.json(200, {'ok': true}),
      ]);
      final res = await client(adapter).get<dynamic>('/health');
      expect(res.statusCode, 200);
      expect(adapter.calls, 3);
    });

    test('GET: desiste após o limite e devolve mensagem de timeout', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.receiveTimeout)]);
      final error = await failureOf(client(adapter).get<dynamic>('/health'));
      expect(error.kind, ApiErrorKind.timeout);
      expect(adapter.calls, 4); // 1 original + 3 novas tentativas
    });

    test('respeita maxRetries configurado', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]);
      final error = await failureOf(
        client(adapter, maxRetries: 1).get<dynamic>('/health'),
      );
      expect(error.kind, ApiErrorKind.network);
      expect(adapter.calls, 2);
    });

    test('GET: repete em 503 e se recupera', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(503, {'error': {'code': 'X', 'message': 'x'}}),
        FakeAdapter.json(200, {'ok': true}),
      ]);
      final res = await client(adapter).get<dynamic>('/health');
      expect(res.statusCode, 200);
      expect(adapter.calls, 2);
    });

    test('POST: NÃO repete após timeout de resposta (evita duplicar cadastro)', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.receiveTimeout)]);
      final error = await failureOf(
        client(adapter).post<dynamic>('/users', data: {'name': 'Ana'}),
      );
      expect(error.kind, ApiErrorKind.timeout);
      expect(adapter.calls, 1);
    });

    test('POST: repete quando nem chegou ao servidor (erro de conexão)', () async {
      final adapter = FakeAdapter([
        FakeAdapter.fail(DioExceptionType.connectionError),
        FakeAdapter.json(201, {'id': '1'}),
      ]);
      final res = await client(adapter).post<dynamic>('/users', data: {'name': 'Ana'});
      expect(res.statusCode, 201);
      expect(adapter.calls, 2);
    });

    test('POST multipart: reenvia o FormData clonado', () async {
      final adapter = FakeAdapter([
        FakeAdapter.fail(DioExceptionType.connectionTimeout),
        FakeAdapter.json(200, {'ok': true}),
      ]);
      final form = FormData.fromMap({'modelVersion': 'v1'});
      final res = await client(adapter).post<dynamic>('/users/1/face', data: form);
      expect(res.statusCode, 200);
      expect(adapter.calls, 2);
    });

    test('erros 4xx não são repetidos', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(404, {'error': {'code': 'NOT_FOUND', 'message': 'Registro não encontrado'}}),
      ]);
      final error = await failureOf(client(adapter).get<dynamic>('/users/9'));
      expect(error.kind, ApiErrorKind.notFound);
      expect(error.message, 'Registro não encontrado');
      expect(adapter.calls, 1);
    });
  });

  group('erros padronizados', () {
    test('DioException sai com ApiException em .error e mensagem simples', () async {
      final adapter = FakeAdapter([
        FakeAdapter.json(409, {'error': {'code': 'CONFLICT', 'message': 'Já existe um registro com esses dados'}}),
      ]);
      try {
        await client(adapter).post<dynamic>('/users', data: {});
        fail('deveria falhar');
      } on DioException catch (e) {
        expect(e.error, isA<ApiException>());
        expect((e.error as ApiException).kind, ApiErrorKind.conflict);
        expect(e.message, 'Já existe um registro com esses dados');
      }
    });
  });

  group('401 / sessão', () {
    test('avisa o app uma única vez', () async {
      var calls = 0;
      final adapter = FakeAdapter([FakeAdapter.json(401, {'error': {'code': 'UNAUTHORIZED', 'message': 'x'}})]);
      final error = await failureOf(
        client(adapter, onUnauthorized: () => calls++).get<dynamic>('/users'),
      );
      expect(error.kind, ApiErrorKind.unauthorized);
      expect(calls, 1);
      expect(adapter.calls, 1);
    });

    test('rotas de login podem ignorar o aviso de sessão expirada', () async {
      var calls = 0;
      final adapter = FakeAdapter([FakeAdapter.json(401, {'error': {'code': 'UNAUTHORIZED', 'message': 'x'}})]);
      await failureOf(
        client(adapter, onUnauthorized: () => calls++).post<dynamic>(
          '/auth/login',
          options: Options(extra: {ErrorInterceptor.skipSessionExpiredKey: true}),
        ),
      );
      expect(calls, 0);
    });
  });

  group('token e URL base', () {
    test('envia Authorization: Bearer quando há token', () async {
      final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
      await client(adapter, readToken: () async => 'abc123').get<dynamic>('/users');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer abc123');
    });

    test('não envia Authorization sem token ou com skipAuth', () async {
      final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
      await client(adapter).get<dynamic>('/health');
      await client(adapter, readToken: () async => 'abc123').get<dynamic>(
        '/auth/login',
        options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
      );
      expect(adapter.requests[0].headers.containsKey('Authorization'), isFalse);
      expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    });

    test('a URL base é relida a cada chamada (sem recompilar)', () async {
      var base = 'http://10.0.2.2:3000/api';
      final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
      final dio = client(adapter, baseUrl: () => base);

      await dio.get<dynamic>('/health');
      base = 'http://192.168.0.10:8080/api';
      await dio.get<dynamic>('/health');

      expect(adapter.requests[0].uri.toString(), 'http://10.0.2.2:3000/api/health');
      expect(adapter.requests[1].uri.toString(), 'http://192.168.0.10:8080/api/health');
    });
  });
}
