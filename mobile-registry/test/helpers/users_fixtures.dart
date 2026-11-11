import 'package:mobile_registry/features/users/data/user_models.dart';

import 'fake_adapter.dart';

/// JSON de um usuário como a listagem do backend devolve.
Map<String, Object?> userJson({
  String id = 'u-1',
  String name = 'Maria Silva',
  String email = 'maria@teste.com',
  String? document = '12345678900',
  String? phone,
  String role = 'RESIDENT',
  bool active = true,
  bool? hasFace,
  int? nfcTagCount,
}) =>
    {
      'id': id,
      'name': name,
      'document': document,
      'email': email,
      'phone': phone,
      'role': role,
      'active': active,
      'createdAt': '2026-01-01T10:00:00.000Z',
      'updatedAt': '2026-01-01T10:00:00.000Z',
      if (hasFace != null) 'hasFace': hasFace,
      if (nfcTagCount != null) 'nfcTagCount': nfcTagCount,
    };

/// JSON do detalhe (`GET /users/{id}`).
Map<String, Object?> detailJson({
  String id = 'u-1',
  String name = 'Maria Silva',
  String email = 'maria@teste.com',
  String? document = '12345678900',
  String? phone = '11999990000',
  String role = 'RESIDENT',
  bool active = true,
  bool hasFace = false,
  bool hasPhoto = false,
  List<Map<String, Object?>> tags = const [],
}) =>
    {
      ...userJson(
        id: id,
        name: name,
        email: email,
        document: document,
        phone: phone,
        role: role,
        active: active,
      ),
      'hasFace': hasFace,
      'hasPhoto': hasPhoto,
      'nfcTags': tags,
    };

Map<String, Object?> tagJson({String id = 't-1', String uid = '04A32F1B'}) => {
      'id': id,
      'uid': uid,
      'userId': 'u-1',
      'active': true,
      'createdAt': '2026-01-01T10:00:00.000Z',
    };

/// Corpo paginado (`{ data, page, pageSize, total, totalPages }`).
Map<String, Object?> pageJson(
  List<Map<String, Object?>> users, {
  int page = 1,
  int pageSize = 20,
  int? total,
  int totalPages = 1,
}) =>
    {
      'data': users,
      'page': page,
      'pageSize': pageSize,
      'total': total ?? users.length,
      'totalPages': totalPages,
    };

FakeHandler usersPage(
  List<Map<String, Object?>> users, {
  int page = 1,
  int? total,
  int totalPages = 1,
}) =>
    FakeAdapter.json(
      200,
      pageJson(users, page: page, total: total, totalPages: totalPages),
    );

FakeHandler apiError(int status, String code, String message, [Object? details]) =>
    FakeAdapter.json(status, {
      'error': {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      },
    });

/// `UserSummary` pronto para testes de lógica.
UserSummary summary({
  String id = 'u-1',
  String name = 'Maria Silva',
  UserRole role = UserRole.resident,
  bool active = true,
}) =>
    UserSummary(
      id: id,
      name: name,
      email: '$id@teste.com',
      role: role,
      active: active,
    );
