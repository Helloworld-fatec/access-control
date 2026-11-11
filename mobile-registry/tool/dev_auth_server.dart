// Servidor de desenvolvimento OPCIONAL: simula o login e a API de usuários do
// backend, em memória, para testar o app enquanto o backend real ainda não
// tem `POST /api/auth/login`.
//
//   dart run tool/dev_auth_server.dart            (porta 3000)
//   dart run tool/dev_auth_server.dart 3001       (outra porta)
//
// Contas de teste (qualquer senha não vazia):
//   admin@teste.com    -> perfil ADMIN    (entra)
//   morador@teste.com  -> perfil RESIDENT (recusado pelo app: acesso negado)
// Outros e-mails -> 401 "E-mail ou senha incorretos."
//
// Usuários (/api/users): 25 usuários de exemplo, mesmo contrato do backend
// (paginação, busca, filtros, validação 400, conflito 409) e tags NFC
// (POST /users/{id}/tags, DELETE /users/{id}/tags/{tagId}; UID repetido -> 409). A listagem aqui já
// devolve `hasFace` e `nfcTagCount`, como o backend passará a fazer (ver
// docs/backend-lista-usuarios.md). Os dados somem ao reiniciar o servidor.
//
// Para testar a expiração de sessão (US-05): abra
//   http://<ip>:3000/api/dev/expire-tokens
// no navegador; os tokens emitidos até agora passam a valer 401.
//
// NÃO usar fora do desenvolvimento: não valida senha e não é seguro.
import 'dart:convert';
import 'dart:io';

typedef Json = Map<String, Object?>;

const _roles = ['ADMIN', 'RESIDENT', 'VISITOR'];
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _uidPattern = RegExp(r'^[0-9A-F]{8,20}$');

/// Tokens emitidos antes deste instante (ms) são recusados com 401.
var _tokensValidAfter = 0;
var _nextId = 1;

final List<Json> _users = _seed();

List<Json> _seed() {
  final names = [
    'Ana Souza', 'Bruno Lima', 'Carla Dias', 'Diego Alves', 'Elisa Rocha',
    'Fábio Costa', 'Gabriela Nunes', 'Hugo Martins', 'Isabela Reis',
    'João Pereira', 'Karina Melo', 'Lucas Barros', 'Marina Teixeira',
    'Nelson Pinto', 'Olívia Campos', 'Paulo Ramos', 'Quitéria Lopes',
    'Rafael Duarte', 'Sofia Araújo', 'Tiago Moreira', 'Úrsula Faria',
    'Vitor Cardoso', 'Wanda Freitas', 'Xavier Borges', 'Yara Cunha',
  ];
  final list = <Json>[];
  for (var i = 0; i < names.length; i++) {
    final role = i == 0 ? 'ADMIN' : (i % 5 == 0 ? 'VISITOR' : 'RESIDENT');
    list.add(_newUser(
      name: names[i],
      email: i == 0 ? 'admin@teste.com' : 'usuario$i@teste.com',
      document: '1000000000${i.toString().padLeft(2, '0')}',
      phone: i % 3 == 0 ? '1199999${i.toString().padLeft(4, '0')}' : null,
      role: role,
      active: i % 7 != 6,
      tags: i % 2 == 0 ? 1 : 0,
      hasFace: i % 3 == 0,
    ));
  }
  return list;
}

Json _newUser({
  required String name,
  required String email,
  String? document,
  String? phone,
  required String role,
  bool active = true,
  int tags = 0,
  bool hasFace = false,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  final id = _uuid(_nextId++);
  return {
    'id': id,
    'name': name,
    'document': document,
    'email': email,
    'phone': phone,
    'role': role,
    'active': active,
    'createdAt': now,
    'updatedAt': now,
    '_tags': [
      for (var t = 0; t < tags; t++)
        {
          'id': _uuid(900000 + _nextId * 10 + t),
          'uid': '04A32F${_nextId.toRadixString(16).toUpperCase().padLeft(2, '0')}1B',
          'userId': id,
          'active': true,
          'createdAt': now,
        },
    ],
    '_hasFace': hasFace,
  };
}

String _uuid(int n) {
  final hex = n.toRadixString(16).padLeft(12, '0');
  return '00000000-0000-4000-8000-$hex';
}

/// Versão da listagem: como o backend passará a devolver.
Json _listItem(Json u) => {
      ..._public(u),
      'hasFace': u['_hasFace'],
      'nfcTagCount': (u['_tags']! as List).length,
    };

/// Versão do detalhe (`GET /users/{id}`).
Json _detail(Json u) => {
      ..._public(u),
      'hasFace': u['_hasFace'],
      'hasPhoto': false,
      'nfcTags': u['_tags'],
    };

Json _public(Json u) => {
      for (final e in u.entries)
        if (!e.key.startsWith('_')) e.key: e.value,
    };

int _clampInt(int value, int low, int high) =>
    value < low ? low : (value > high ? high : value);

bool _tokenIsValid(String? authorization) {
  const prefix = 'Bearer dev-token-';
  if (authorization == null || !authorization.startsWith(prefix)) return false;
  final issuedAt = int.tryParse(authorization.substring(prefix.length));
  return issuedAt != null && issuedAt >= _tokensValidAfter;
}

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 3000 : 3000;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Servidor de desenvolvimento em http://0.0.0.0:$port/api');
  stdout.writeln('Login: admin@teste.com (ADMIN) | morador@teste.com (RESIDENT)');

  await for (final request in server) {
    try {
      await _handle(request);
    } catch (_) {
      await _send(request, 500, _error('INTERNAL_ERROR', 'Erro interno.'));
    }
  }
}

Future<void> _handle(HttpRequest request) async {
  final method = request.method;
  final segments = request.uri.pathSegments;
  stdout.writeln('$method ${request.uri.path}');

  if (segments.length < 2 || segments[0] != 'api') {
    return _send(request, 404, _error('NOT_FOUND', 'Rota não encontrada.'));
  }

  if (method == 'GET' && segments[1] == 'health') {
    return _send(request, 200, {'status': 'ok'});
  }

  if (method == 'POST' && segments[1] == 'auth' && segments.length == 3 && segments[2] == 'login') {
    return _login(request);
  }

  // Só para desenvolvimento: invalida todos os tokens emitidos até agora.
  if (method == 'GET' && segments[1] == 'dev' && segments.length == 3 && segments[2] == 'expire-tokens') {
    _tokensValidAfter = DateTime.now().millisecondsSinceEpoch + 1;
    return _send(request, 200, {'expired': true});
  }

  if (segments[1] == 'users') {
    if (!_tokenIsValid(request.headers.value('authorization'))) {
      return _send(
        request,
        401,
        _error('UNAUTHORIZED', 'Token ausente, inválido ou expirado.'),
      );
    }
    return _usersRoutes(request, segments.sublist(2));
  }

  return _send(request, 404, _error('NOT_FOUND', 'Rota não encontrada.'));
}

// ------------------------------------------------------------------- login

Future<void> _login(HttpRequest request) async {
  final body = await _readJson(request);
  if (body == null) {
    return _send(request, 400, _error('VALIDATION_ERROR', 'Dados inválidos'));
  }
  final email = '${body['email'] ?? ''}'.trim().toLowerCase();
  final password = '${body['password'] ?? ''}';

  Json? found;
  for (final u in _users) {
    if (u['email'] == email) found = u;
  }
  // Conta de exemplo extra, só para testar o acesso negado.
  found ??= email == 'morador@teste.com'
      ? _newUser(name: 'Bruno Lima', email: email, role: 'RESIDENT')
      : null;

  if (found == null || password.isEmpty || found['active'] == false) {
    return _send(
      request,
      401,
      _error('INVALID_CREDENTIALS', 'E-mail ou senha incorretos.'),
    );
  }
  return _send(request, 200, {
    'accessToken': 'dev-token-${DateTime.now().millisecondsSinceEpoch}',
    'user': _public(found),
  });
}

// ---------------------------------------------------------------- usuários

Future<void> _usersRoutes(HttpRequest request, List<String> rest) async {
  final method = request.method;

  // /api/users
  if (rest.isEmpty) {
    if (method == 'GET') return _listUsers(request);
    if (method == 'POST') return _createUser(request);
  }

  // /api/users/{id}
  if (rest.length == 1) {
    final user = _find(rest[0]);
    if (user == null) return _notFound(request);
    if (method == 'GET') return _send(request, 200, _detail(user));
    if (method == 'PUT') return _updateUser(request, user);
  }

  // /api/users/{id}/status
  if (rest.length == 2 && rest[1] == 'status' && method == 'PATCH') {
    final user = _find(rest[0]);
    if (user == null) return _notFound(request);
    final body = await _readJson(request);
    if (body == null || body['active'] is! bool) {
      return _validation(request, [
        {'path': 'active', 'message': 'Invalid input'},
      ]);
    }
    user['active'] = body['active'];
    user['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    return _send(request, 200, _public(user));
  }

  // /api/users/{id}/tags
  if (rest.length == 2 && rest[1] == 'tags' && method == 'POST') {
    final user = _find(rest[0]);
    if (user == null) return _notFound(request);
    return _addTag(request, user);
  }

  // /api/users/{id}/tags/{tagId}
  if (rest.length == 3 && rest[1] == 'tags' && method == 'DELETE') {
    final user = _find(rest[0]);
    if (user == null) return _notFound(request);
    final tags = user['_tags']! as List;
    final before = tags.length;
    tags.removeWhere((t) => (t as Map)['id'] == rest[2]);
    if (tags.length == before) {
      return _send(request, 404, _error('TAG_NOT_FOUND', 'Tag não encontrada'));
    }
    return _noContent(request);
  }

  return _send(request, 404, _error('NOT_FOUND', 'Rota não encontrada.'));
}

Future<void> _addTag(HttpRequest request, Json user) async {
  final body = await _readJson(request);
  final uid = body?['uid'];
  if (uid is! String || !_uidPattern.hasMatch(uid)) {
    return _validation(request, [
      {'path': 'uid', 'message': 'UID inválido'},
    ]);
  }
  // O mesmo UID não pode estar em dois lugares. A mensagem é genérica: não
  // revela de quem é a tag.
  for (final u in _users) {
    for (final t in u['_tags']! as List) {
      if ((t as Map)['uid'] == uid) {
        return _send(request, 409, _error('TAG_CONFLICT', 'Esta tag já está cadastrada'));
      }
    }
  }
  final tag = <String, Object?>{
    'id': _uuid(800000 + _nextId++),
    'uid': uid,
    'userId': user['id'],
    'active': true,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  };
  (user['_tags']! as List).add(tag);
  return _send(request, 201, tag);
}

Json? _find(String id) {
  for (final u in _users) {
    if (u['id'] == id) return u;
  }
  return null;
}

Future<void> _listUsers(HttpRequest request) async {
  final q = request.uri.queryParameters;
  final page = _clampInt(int.tryParse(q['page'] ?? '') ?? 1, 1, 1000000);
  final pageSize = _clampInt(int.tryParse(q['pageSize'] ?? '') ?? 20, 1, 100);
  final search = (q['search'] ?? '').trim().toLowerCase();
  final role = q['role'];
  final active = q['active'];

  final filtered = _users.where((u) {
    if (role != null && u['role'] != role) return false;
    if (active != null && '${u['active']}' != active) return false;
    if (search.isNotEmpty) {
      final name = '${u['name']}'.toLowerCase();
      final doc = '${u['document'] ?? ''}';
      if (!name.contains(search) && !doc.contains(search)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

  final start = (page - 1) * pageSize;
  final slice = start >= filtered.length
      ? <Json>[]
      : filtered.sublist(start, _clampInt(start + pageSize, 0, filtered.length));

  return _send(request, 200, {
    'data': slice.map(_listItem).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': filtered.length,
    'totalPages': _clampInt((filtered.length / pageSize).ceil(), 1, 1000000),
  });
}

List<Json> _validate(Json body, {required bool partial}) {
  final errors = <Json>[];
  void add(String path, String message) =>
      errors.add({'path': path, 'message': message});

  bool has(String k) => body.containsKey(k);
  final name = body['name'];
  if (!partial || has('name')) {
    if (name is! String || name.trim().length < 2) add('name', 'Nome muito curto');
  }
  final email = body['email'];
  if (!partial || has('email')) {
    if (email is! String || !_emailPattern.hasMatch(email.trim())) {
      add('email', 'E-mail inválido');
    }
  }
  final password = body['password'];
  if (!partial || has('password')) {
    if (password is! String || password.length < 6) {
      add('password', 'Senha deve ter ao menos 6 caracteres');
    }
  }
  if (!partial || has('role')) {
    if (!_roles.contains(body['role'])) add('role', 'Perfil inválido');
  }
  return errors;
}

bool _conflicts(Json body, {String? ignoreId}) {
  final email = body['email'] is String ? (body['email']! as String).trim().toLowerCase() : null;
  final doc = body['document'] is String ? (body['document']! as String).trim() : null;
  for (final u in _users) {
    if (u['id'] == ignoreId) continue;
    if (email != null && email.isNotEmpty && u['email'] == email) return true;
    if (doc != null && doc.isNotEmpty && u['document'] == doc) return true;
  }
  return false;
}

String? _optional(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

Future<void> _createUser(HttpRequest request) async {
  final body = await _readJson(request);
  if (body == null) return _validation(request, []);
  final errors = _validate(body, partial: false);
  if (errors.isNotEmpty) return _validation(request, errors);
  if (_conflicts(body)) return _conflict(request);

  final user = _newUser(
    name: (body['name']! as String).trim(),
    email: (body['email']! as String).trim().toLowerCase(),
    document: _optional(body['document']),
    phone: _optional(body['phone']),
    role: body['role']! as String,
  );
  _users.add(user);
  return _send(request, 201, _public(user));
}

Future<void> _updateUser(HttpRequest request, Json user) async {
  final body = await _readJson(request);
  if (body == null) return _validation(request, []);
  final errors = _validate(body, partial: true);
  if (body.isEmpty) errors.add({'path': '', 'message': 'Envie ao menos um campo'});
  if (errors.isNotEmpty) return _validation(request, errors);
  if (_conflicts(body, ignoreId: user['id'] as String)) return _conflict(request);

  // Como no backend: texto opcional em branco é ignorado (não apaga o valor).
  if (body['name'] is String) user['name'] = (body['name']! as String).trim();
  if (body['email'] is String) {
    user['email'] = (body['email']! as String).trim().toLowerCase();
  }
  final doc = _optional(body['document']);
  if (doc != null) user['document'] = doc;
  final phone = _optional(body['phone']);
  if (phone != null) user['phone'] = phone;
  if (body['role'] is String) user['role'] = body['role'];
  user['updatedAt'] = DateTime.now().toUtc().toIso8601String();
  return _send(request, 200, _public(user));
}

// ----------------------------------------------------------------- helpers

Future<Json?> _readJson(HttpRequest request) async {
  try {
    final raw = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

Future<void> _validation(HttpRequest request, List<Json> details) => _send(
      request,
      400,
      {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Dados inválidos',
          'details': details,
        },
      },
    );

Future<void> _conflict(HttpRequest request) => _send(
      request,
      409,
      _error('USER_CONFLICT', 'E-mail ou documento já cadastrado'),
    );

Future<void> _notFound(HttpRequest request) => _send(
      request,
      404,
      _error('USER_NOT_FOUND', 'Usuário não encontrado'),
    );

Json _error(String code, String message) => {
      'error': {'code': code, 'message': message},
    };

Future<void> _noContent(HttpRequest request) async {
  request.response.statusCode = 204;
  await request.response.close();
}

Future<void> _send(HttpRequest request, int status, Object body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}
