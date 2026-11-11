import 'package:flutter/foundation.dart';

/// Configurações editáveis em tempo de execução (sem recompilar).
@immutable
class AppSettings {
  const AppSettings({
    required this.host,
    required this.port,
    required this.maxPhotoKb,
    required this.faceSamples,
  });

  /// 10.0.2.2 é o "localhost" da máquina host quando se usa o emulador Android.
  static const String defaultHost = '10.0.2.2';
  static const int defaultPort = 3000;
  static const int defaultMaxPhotoKb = 50;
  static const int defaultFaceSamples = 3;

  static const AppSettings defaults = AppSettings(
    host: defaultHost,
    port: defaultPort,
    maxPhotoKb: defaultMaxPhotoKb,
    faceSamples: defaultFaceSamples,
  );

  /// Endereço IPv4 do backend (ex.: 192.168.0.10).
  final String host;
  final int port;

  /// Tamanho máximo da foto enviada, em KB (padrão 50).
  final int maxPhotoKb;

  /// Quantidade de capturas do rosto por cadastro (3 a 5).
  final int faceSamples;

  /// Todas as rotas do backend ficam sob o prefixo /api.
  String get baseUrl => 'http://$host:$port/api';

  int get maxPhotoBytes => maxPhotoKb * 1024;

  AppSettings copyWith({
    String? host,
    int? port,
    int? maxPhotoKb,
    int? faceSamples,
  }) {
    return AppSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      maxPhotoKb: maxPhotoKb ?? this.maxPhotoKb,
      faceSamples: faceSamples ?? this.faceSamples,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.host == host &&
      other.port == port &&
      other.maxPhotoKb == maxPhotoKb &&
      other.faceSamples == faceSamples;

  @override
  int get hashCode => Object.hash(host, port, maxPhotoKb, faceSamples);

  @override
  String toString() =>
      'AppSettings($baseUrl, foto<=${maxPhotoKb}KB, capturas=$faceSamples)';
}
