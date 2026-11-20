import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/interceptors/error_interceptor.dart';
import '../../../core/network/interceptors/request_interceptors.dart';
import '../../../core/network/interceptors/retry_interceptor.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';

const registryApiUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3333/api',
);

enum SessionEndReason { signedOut, expired }

class SessionController extends ChangeNotifier {
  SessionController({
    String baseUrl = registryApiUrl,
    HttpClientAdapter? adapter,
    Duration Function(int attempt)? retryDelay,
  }) : _server = Uri.parse(baseUrl) {
    dio = createApiClient(
      baseUrl: () => _server.toString(),
      readToken: () async => _token,
      onUnauthorized: expire,
      adapter: adapter,
      retryDelay: retryDelay,
    );
  }

  late final Dio dio;
  Uri _server;
  String? _token;
  AuthUser? _user;
  SessionEndReason? _endReason;
  bool _loading = false;
  bool _checking = false;
  bool _disposed = false;
  String? _error;

  AuthUser? get user => _user;
  SessionEndReason? get endReason => _endReason;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  bool get checking => _checking;
  bool get busy => _loading || _checking;
  Uri get server => _server;
  String? get error => _error;

  void startSession(AuthUser user, String token) {
    _token = token;
    _user = user;
    _endReason = null;
    _error = null;
    notifyListeners();
  }

  Future<String?> checkConnection(Uri server) async {
    if (busy || isAuthenticated || _disposed) return 'Conexão em uso.';
    _server = server;
    _checking = true;
    _error = null;
    notifyListeners();
    final cancelToken = CancelToken();
    final timer = Timer(const Duration(seconds: 4), () => cancelToken.cancel());
    try {
      final response = await dio.get<dynamic>(
        '/health',
        cancelToken: cancelToken,
        options: Options(
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          extra: {
            AuthInterceptor.skipAuthKey: true,
            ErrorInterceptor.skipSessionExpiredKey: true,
            RetryInterceptor.skipRetryKey: true,
          },
        ),
      );
      if (response.statusCode == 200 && _healthy(response.data)) return null;
      return 'O endereço respondeu, mas o serviço de saúde da API não retornou OK.';
    } on DioException {
      return 'Não foi possível alcançar o servidor. Confira o IP, a porta e a rede.';
    } finally {
      timer.cancel();
      _checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> submit({
    required String email,
    required String password,
    Uri? server,
  }) async {
    if (busy || isAuthenticated || _disposed) return;
    if (server != null) _server = server;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final (user, token) = await AuthRepository(dio)
          .login(email: email, password: password);
      if (!_disposed) startSession(user, token);
    } catch (error) {
      _error = userMessageFor(error);
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _healthy(Object? body) {
    if (body is! String) return false;
    try {
      final result = jsonDecode(body);
      return result is Map && result['status'] == 'ok';
    } on FormatException {
      return false;
    }
  }

  void signOut() => _endSession(SessionEndReason.signedOut);

  void expire(String? sentToken) {
    if (sentToken == null || sentToken == _token) {
      _endSession(SessionEndReason.expired);
    }
  }

  void _endSession(SessionEndReason reason) {
    if (_disposed || _user == null) return;
    _token = null;
    _user = null;
    _error = null;
    _endReason = reason;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    dio.close(force: true);
    super.dispose();
  }
}
