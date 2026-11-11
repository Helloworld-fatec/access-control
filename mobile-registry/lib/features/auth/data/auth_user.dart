import 'package:flutter/foundation.dart';

/// Dados mínimos do usuário autenticado (retornados por `POST /auth/login`).
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  /// Único perfil que pode usar este aplicativo.
  static const String adminRole = 'ADMIN';

  final String id;
  final String name;
  final String email;

  /// `ADMIN`, `RESIDENT` ou `VISITOR`.
  final String role;

  bool get isAdmin => role == adminRole;

  /// Primeiro nome, para saudações ("Olá, Ana").
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Lê o objeto `user` da resposta do backend. Lança [FormatException] se
  /// faltar algum campo, para nunca guardarmos uma sessão incompleta.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
      throw FormatException('Campo "$key" ausente ou inválido');
    }

    return AuthUser(
      id: field('id'),
      name: field('name'),
      email: field('email'),
      role: field('role'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, email, role);

  @override
  String toString() => 'AuthUser($id, $role)';
}
