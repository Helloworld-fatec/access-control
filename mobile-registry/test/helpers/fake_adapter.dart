import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

/// Servidor falso: responde na ordem de [script] (repete o último item
/// quando as respostas acabam) e registra cada requisição recebida.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this._script);

  final List<FakeHandler> _script;
  final List<RequestOptions> requests = [];

  int get calls => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    final index = requests.length - 1;
    final handler = _script[index < _script.length ? index : _script.length - 1];
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static FakeHandler json(int status, Object body) => (options) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  static FakeHandler fail(DioExceptionType type) => (options) async {
        throw DioException(requestOptions: options, type: type);
      };
}
