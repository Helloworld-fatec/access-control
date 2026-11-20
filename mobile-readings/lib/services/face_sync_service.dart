import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/terminal_config.dart';

/// Embedding facial mantido exclusivamente em memória no terminal (US-15).
class AuthorizedFaceEmbedding {
  final String userId;
  final List<double> embedding;
  final String modelVersion;

  const AuthorizedFaceEmbedding({
    required this.userId,
    required this.embedding,
    required this.modelVersion,
  });
}

/// Resultado da comparação facial local no terminal (US-17).
class FaceMatchResult {
  final String userId;
  final double similarity;

  const FaceMatchResult({
    required this.userId,
    required this.similarity,
  });
}

/// Serviço de sincronização em memória e comparação local de embeddings faciais (US-15, US-17).
/// Nenhum dado biométrico é gravado em disco no aparelho.
class FaceSyncService {
  static const String currentModelVersion = 'mobilefacenet-v1';

  final http.Client _httpClient;
  final List<AuthorizedFaceEmbedding> _memoryEmbeddings = [];

  FaceSyncService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  List<AuthorizedFaceEmbedding> get authorizedEmbeddings =>
      List.unmodifiable(_memoryEmbeddings);

  /// Sincroniza a lista de embeddings autorizados em GET /terminals/{id}/faces (US-15).
  /// Embeddings com `modelVersion` diferente de [expectedModelVersion] são descartados.
  Future<int> syncEmbeddings(
    TerminalConfig config, {
    String expectedModelVersion = currentModelVersion,
  }) async {
    final uri = Uri.parse(
      '${config.backendBaseUrl}/terminals/${config.terminalId}/faces',
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      if (config.apiKey.trim().isNotEmpty) 'x-api-key': config.apiKey.trim(),
    };

    final response = await _httpClient
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha ao sincronizar embeddings (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final items = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : const []);

    _memoryEmbeddings.clear();
    for (final raw in items) {
      if (raw is! Map) continue;
      final version = raw['modelVersion']?.toString() ?? '';
      if (version != expectedModelVersion) {
        // Descarta embeddings de versão incompatível (US-15)
        continue;
      }
      final userId = raw['userId']?.toString() ?? '';
      final rawVector = raw['embedding'];
      if (userId.isEmpty || rawVector is! List || rawVector.isEmpty) continue;

      final vector =
          rawVector.map((e) => (e as num).toDouble()).toList(growable: false);
      _memoryEmbeddings.add(
        AuthorizedFaceEmbedding(
          userId: userId,
          embedding: vector,
          modelVersion: version,
        ),
      );
    }

    return _memoryEmbeddings.length;
  }

  /// Limpa os embeddings da memória RAM.
  void clearMemory() {
    _memoryEmbeddings.clear();
  }

  /// Compara um embedding capturado localmente com a lista em memória via similaridade cosseno (US-17).
  /// Retorna apenas correspondência acima de [threshold]; caso contrário retorna `null`.
  FaceMatchResult? findBestMatch(
    List<double> capturedEmbedding, {
    required double threshold,
  }) {
    if (_memoryEmbeddings.isEmpty || capturedEmbedding.isEmpty) return null;

    String? bestUser;
    double bestScore = -1.0;

    for (final item in _memoryEmbeddings) {
      if (item.embedding.length != capturedEmbedding.length) continue;
      final score = cosineSimilarity(capturedEmbedding, item.embedding);
      if (score > bestScore) {
        bestScore = score;
        bestUser = item.userId;
      }
    }

    if (bestUser != null && bestScore >= threshold) {
      return FaceMatchResult(userId: bestUser, similarity: bestScore);
    }
    return null;
  }

  /// Similaridade de cosseno entre dois vetores de mesma dimensão.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) {
      throw ArgumentError('Vetores devem ter o mesmo tamanho e não ser vazios.');
    }
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    if (denom == 0.0) return 0.0;
    return dot / denom;
  }
}
