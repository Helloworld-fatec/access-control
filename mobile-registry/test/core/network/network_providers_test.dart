import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/config/app_settings.dart';
import 'package:mobile_registry/core/config/settings_providers.dart';
import 'package:mobile_registry/core/network/api_exception.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/features/settings/data/connection_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_adapter.dart';

Future<ProviderContainer> containerWith(FakeAdapter adapter) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    httpClientAdapterProvider.overrideWithValue(adapter),
    retryDelayProvider.overrideWithValue((_) => Duration.zero),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('salvar as configurações vale imediatamente para o cliente HTTP', () async {
    final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
    final container = await containerWith(adapter);
    final dio = container.read(dioProvider);

    await dio.get<dynamic>('/health');
    await container.read(settingsProvider.notifier).save(
          const AppSettings(
            host: '192.168.0.10',
            port: 8080,
            maxPhotoKb: 50,
            faceSamples: 3,
          ),
        );
    await dio.get<dynamic>('/health');

    expect(adapter.requests[0].uri.toString(), 'http://10.0.2.2:3000/api/health');
    expect(adapter.requests[1].uri.toString(), 'http://192.168.0.10:8080/api/health');
  });

  test('o token do TokenStore é enviado pelo cliente único', () async {
    final adapter = FakeAdapter([FakeAdapter.json(200, {})]);
    final container = await containerWith(adapter);
    await container.read(tokenStoreProvider).write('tok');
    await container.read(dioProvider).get<dynamic>('/users');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('401 dispara o evento de sessão expirada', () async {
    final adapter = FakeAdapter([
      FakeAdapter.json(401, {'error': {'code': 'UNAUTHORIZED', 'message': 'x'}}),
    ]);
    final container = await containerWith(adapter);
    expect(container.read(sessionExpiredProvider), 0);
    await expectLater(
      container.read(dioProvider).get<dynamic>('/users'),
      throwsA(isA<DioException>()),
    );
    expect(container.read(sessionExpiredProvider), 1);
  });

  group('ConnectionRepository', () {
    test('sucesso quando /health responde 200', () async {
      final adapter = FakeAdapter([FakeAdapter.json(200, {'status': 'ok'})]);
      final container = await containerWith(adapter);
      await container.read(connectionRepositoryProvider).check();
      expect(adapter.requests.single.uri.path, '/api/health');
    });

    test('falha vira ApiException amigável', () async {
      final adapter = FakeAdapter([FakeAdapter.fail(DioExceptionType.connectionError)]);
      final container = await containerWith(adapter);
      await expectLater(
        container.read(connectionRepositoryProvider).check(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.network)
              .having((e) => e.message, 'message', ApiException.networkMessage),
        ),
      );
    });
  });
}
