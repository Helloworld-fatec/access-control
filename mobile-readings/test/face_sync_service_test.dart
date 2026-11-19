import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_readings/config/terminal_config.dart';
import 'package:mobile_readings/services/face_sync_service.dart';

class _MockFacesHttp extends http.BaseClient {
  int statusCode;
  dynamic responseBody;

  _MockFacesHttp({
    this.statusCode = 200,
    this.responseBody,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyStr = jsonEncode(responseBody ?? []);
    return http.StreamedResponse(
      Stream.value(utf8.encode(bodyStr)),
      statusCode,
    );
  }
}

void main() {
  group('FaceSyncService (US-15, US-17, US-19)', () {
    const config = TerminalConfig(
      backendHost: 'localhost',
      backendPort: 3000,
      terminalId: 'term-01',
      faceSimilarityThreshold: 0.75,
    );

    test('calcula similaridade de cosseno com precisão matemática', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      final v3 = [0.0, 1.0, 0.0];

      expect(FaceSyncService.cosineSimilarity(v1, v2), closeTo(1.0, 0.0001));
      expect(FaceSyncService.cosineSimilarity(v1, v3), closeTo(0.0, 0.0001));
    });

    test('sincroniza embeddings compatíveis e ignora versões incompatíveis (US-15)',
        () async {
      final mockHttp = _MockFacesHttp(
        responseBody: {
          'data': [
            {
              'userId': 'user-1',
              'embedding': [0.5, 0.5, 0.5],
              'modelVersion': 'mobilefacenet-v1',
            },
            {
              'userId': 'user-2-invalido',
              'embedding': [0.2, 0.8, 0.1],
              'modelVersion': 'versao-antiga-v0', // deve ser descartado
            },
          ],
        },
      );

      final service = FaceSyncService(httpClient: mockHttp);
      final count = await service.syncEmbeddings(config);

      expect(count, equals(1));
      expect(service.authorizedEmbeddings.length, equals(1));
      expect(service.authorizedEmbeddings.first.userId, equals('user-1'));
    });

    test('findBestMatch retorna usuário correto quando acima do limiar (US-17)',
        () async {
      final mockHttp = _MockFacesHttp(
        responseBody: [
          {
            'userId': 'alice',
            'embedding': [1.0, 0.0, 0.0],
            'modelVersion': 'mobilefacenet-v1',
          },
          {
            'userId': 'bob',
            'embedding': [0.0, 1.0, 0.0],
            'modelVersion': 'mobilefacenet-v1',
          },
        ],
      );

      final service = FaceSyncService(httpClient: mockHttp);
      await service.syncEmbeddings(config);

      // Vetor muito próximo de alice [0.98, 0.05, 0.0]
      final match = service.findBestMatch([0.98, 0.05, 0.0], threshold: 0.75);
      expect(match, isNotNull);
      expect(match!.userId, equals('alice'));
      expect(match.similarity, greaterThan(0.95));

      // Vetor que não atinge o limiar
      final noMatch =
          service.findBestMatch([0.5, 0.5, 0.7], threshold: 0.90);
      expect(noMatch, isNull);
    });

    test('clearMemory limpa completamente os vetores da memória RAM (US-15)',
        () async {
      final mockHttp = _MockFacesHttp(
        responseBody: [
          {
            'userId': 'user-1',
            'embedding': [1.0, 0.0],
            'modelVersion': 'mobilefacenet-v1',
          },
        ],
      );

      final service = FaceSyncService(httpClient: mockHttp);
      await service.syncEmbeddings(config);
      expect(service.authorizedEmbeddings.length, equals(1));

      service.clearMemory();
      expect(service.authorizedEmbeddings.isEmpty, isTrue);
    });

    test('syncEmbeddings lanca excecao quando o servidor retorna erro HTTP (US-15)',
        () async {
      final mockHttp = _MockFacesHttp(
        statusCode: 500,
        responseBody: {'error': 'Internal server error'},
      );

      final service = FaceSyncService(httpClient: mockHttp);
      expect(
        () => service.syncEmbeddings(config),
        throwsA(isA<Exception>()),
      );
    });
  });
}
