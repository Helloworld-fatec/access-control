import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_adapter.dart';

/// Servidor falso por rota: cada chamada é atendida pelo handler registrado
/// para "MÉTODO /caminho" (ex.: `GET /users`). Rota sem handler responde 404.
///
/// Herda de [FakeAdapter] para reaproveitar `requests` e `calls`.
class RoutedAdapter extends FakeAdapter {
  RoutedAdapter(this.routes) : super(const []);

  /// Pode ser alterado durante o teste para mudar as respostas.
  final Map<String, FakeHandler> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler != null) return handler(options);
    return FakeAdapter.json(404, {
      'error': {'code': 'NOT_FOUND', 'message': 'Rota não encontrada.'},
    })(options);
  }

  /// Quantas chamadas houve a "MÉTODO /caminho".
  int callsTo(String route) => requests
      .where((r) => '${r.method} ${r.path}' == route)
      .length;
}
