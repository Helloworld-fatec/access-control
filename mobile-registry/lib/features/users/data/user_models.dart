import 'package:flutter/foundation.dart';

/// Perfis de usuário previstos pelo backend.
enum UserRole {
  admin('ADMIN', 'Administrador'),
  resident('RESIDENT', 'Condômino'),
  visitor('VISITOR', 'Visitante');

  const UserRole(this.value, this.label);

  /// Valor trocado com a API.
  final String value;

  /// Nome mostrado ao usuário.
  final String label;

  /// Converte o texto da API. Perfil desconhecido lança [FormatException]
  /// (resposta fora do contrato).
  static UserRole parse(Object? raw) {
    for (final role in values) {
      if (role.value == raw) return role;
    }
    throw FormatException('Perfil desconhecido: $raw');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Campo "$key" ausente ou inválido');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  throw FormatException('Campo "$key" inválido');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('Campo "$key" ausente ou inválido');
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('Campo "$key" inválido');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Campo "$key" inválido');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _optionalInt(json, key);
  if (value != null) return value;
  throw FormatException('Campo "$key" ausente');
}

Map<String, dynamic> _asMap(Object? value, String what) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$what deveria ser um objeto');
}

/// Usuário como aparece na listagem (`GET /users`).
///
/// A API devolve [hasFace] e [nfcTagCount] só no detalhe (`GET /users/{id}`);
/// na lista eles ficam `null` ("não informado") até o backend incluí-los.
@immutable
class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.document,
    this.phone,
    this.hasFace,
    this.nfcTagCount,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;
  final String? document;
  final String? phone;

  /// Há rosto cadastrado? `null` quando a API não informou.
  final bool? hasFace;

  /// Quantas tags NFC estão vinculadas? `null` quando a API não informou.
  final int? nfcTagCount;

  /// Há tag NFC vinculada? `null` quando a API não informou.
  bool? get hasNfcTag => nfcTagCount == null ? null : nfcTagCount! > 0;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      email: _requiredString(json, 'email'),
      role: UserRole.parse(json['role']),
      active: _requiredBool(json, 'active'),
      document: _optionalString(json, 'document'),
      phone: _optionalString(json, 'phone'),
      hasFace: _optionalBool(json, 'hasFace'),
      nfcTagCount: _optionalInt(json, 'nfcTagCount'),
    );
  }

  UserSummary copyWith({bool? active, bool? hasFace, int? nfcTagCount}) {
    return UserSummary(
      id: id,
      name: name,
      email: email,
      role: role,
      active: active ?? this.active,
      document: document,
      phone: phone,
      hasFace: hasFace ?? this.hasFace,
      nfcTagCount: nfcTagCount ?? this.nfcTagCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserSummary &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.role == role &&
      other.active == active &&
      other.document == document &&
      other.phone == phone &&
      other.hasFace == hasFace &&
      other.nfcTagCount == nfcTagCount;

  @override
  int get hashCode => Object.hash(
        id, name, email, role, active, document, phone, hasFace, nfcTagCount);
}

/// Tag NFC vinculada a um usuário.
@immutable
class NfcTag {
  const NfcTag({required this.id, required this.uid, required this.active});

  final String id;
  final String uid;
  final bool active;

  factory NfcTag.fromJson(Map<String, dynamic> json) {
    return NfcTag(
      id: _requiredString(json, 'id'),
      uid: _requiredString(json, 'uid'),
      active: _requiredBool(json, 'active'),
    );
  }
}

/// Usuário completo (`GET /users/{id}`).
@immutable
class UserDetail {
  const UserDetail({
    required this.user,
    required this.hasFace,
    required this.hasPhoto,
    required this.nfcTags,
  });

  final UserSummary user;
  final bool hasFace;
  final bool hasPhoto;
  final List<NfcTag> nfcTags;

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    final rawTags = json['nfcTags'];
    if (rawTags is! List) {
      throw const FormatException('Campo "nfcTags" ausente ou inválido');
    }
    final tags = [
      for (final tag in rawTags) NfcTag.fromJson(_asMap(tag, 'Tag')),
    ];
    final hasFace = _requiredBool(json, 'hasFace');
    return UserDetail(
      user: UserSummary.fromJson(json)
          .copyWith(hasFace: hasFace, nfcTagCount: tags.length),
      hasFace: hasFace,
      hasPhoto: _requiredBool(json, 'hasPhoto'),
      nfcTags: tags,
    );
  }

  /// Mesma pessoa com outra lista de tags (após vincular, remover ou substituir).
  UserDetail withTags(List<NfcTag> tags) => UserDetail(
        user: user.copyWith(nfcTagCount: tags.length),
        hasFace: hasFace,
        hasPhoto: hasPhoto,
        nfcTags: List.unmodifiable(tags),
      );

  UserDetail withUser(UserSummary updated) => UserDetail(
        user: updated.copyWith(hasFace: hasFace, nfcTagCount: nfcTags.length),
        hasFace: hasFace,
        hasPhoto: hasPhoto,
        nfcTags: nfcTags,
      );
}

/// Uma página da listagem (`{ data, page, pageSize, total, totalPages }`).
@immutable
class UsersPage {
  const UsersPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final List<UserSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory UsersPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('Campo "data" ausente ou inválido');
    }
    return UsersPage(
      items: [
        for (final item in data) UserSummary.fromJson(_asMap(item, 'Usuário')),
      ],
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      total: _requiredInt(json, 'total'),
      totalPages: _requiredInt(json, 'totalPages'),
    );
  }
}

/// Dados do formulário para criar um usuário (`POST /users`).
@immutable
class NewUser {
  const NewUser({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.document,
    this.phone,
  });

  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String? document;
  final String? phone;

  /// Campos opcionais em branco não são enviados.
  Map<String, Object> toJson() => {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'role': role.value,
        if (document != null && document!.trim().isNotEmpty)
          'document': document!.trim(),
        if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      };
}
