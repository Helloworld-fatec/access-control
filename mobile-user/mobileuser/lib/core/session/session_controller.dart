import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';

class SessionController extends ChangeNotifier {
  static const _store = FlutterSecureStorage();
  final _http = http.Client();
  String? backendUrl, token;
  Map<String, dynamic>? user;
  bool initializing = true;
  bool get authenticated => backendUrl != null && token != null;
  ApiClient get _api => ApiClient(backendUrl!, token, _http);

  Future<void> restore() async {
    try {
      final v = await Future.wait([
        _store.read(key: 'access_token'),
        _store.read(key: 'backend_url'),
        _store.read(key: 'session_user'),
      ]);
      if (v[0] != null && v[1] != null) {
        token = v[0];
        backendUrl = ApiClient.normalize(v[1]!);
        user = v[2] == null ? null : jsonDecode(v[2]!) as Map<String, dynamic>;
        try {
          await _api.authorizations();
        } on ApiException catch (e) {
          if (e.statusCode == 401) await logout(notify: false);
        } catch (_) {}
      }
    } catch (_) {
      await logout(notify: false);
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> login(String url, String email, String password) async {
    final base = ApiClient.normalize(url);
    final r = await ApiClient(base, null, _http).login(email.trim(), password);
    final t = r['accessToken'];
    final u = r['user'];
    if (t is! String || u is! Map<String, dynamic>)
      throw const ApiException('Resposta de login incompleta.');
    await _store.write(key: 'access_token', value: t);
    await _store.write(key: 'backend_url', value: base);
    await _store.write(key: 'session_user', value: jsonEncode(u));
    backendUrl = base;
    token = t;
    user = u;
    notifyListeners();
  }

  Future<Map<String, dynamic>> loadAuthorizations() async {
    try {
      return await _api.authorizations();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await logout();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> consumeQr(String value) async {
    try {
      return await _api.consumeQr(value);
    } on QrConsumeException catch (e) {
      if (e.statusCode == 401 && e.code != 'INVALID_CREDENTIAL') await logout();
      rethrow;
    }
  }

  Future<void> logout({bool notify = true}) async {
    await Future.wait([
      _store.delete(key: 'access_token'),
      _store.delete(key: 'backend_url'),
      _store.delete(key: 'session_user'),
    ]);
    token = null;
    backendUrl = null;
    user = null;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}
