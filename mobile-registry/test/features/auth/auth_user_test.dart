import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/features/auth/data/auth_user.dart';

void main() {
  const json = {
    'id': 'u1',
    'name': 'Ana Souza',
    'email': 'admin@teste.com',
    'role': 'ADMIN',
  };

  test('lê o usuário da resposta e ignora campos extras', () {
    final user = AuthUser.fromJson({...json, 'active': true, 'phone': '1'});
    expect(user.id, 'u1');
    expect(user.name, 'Ana Souza');
    expect(user.email, 'admin@teste.com');
    expect(user.role, 'ADMIN');
    expect(user.isAdmin, isTrue);
  });

  test('só ADMIN é administrador', () {
    for (final role in ['RESIDENT', 'VISITOR', 'admin', 'Admin']) {
      final user = AuthUser.fromJson({...json, 'role': role});
      expect(user.isAdmin, isFalse, reason: role);
    }
  });

  test('campo ausente, vazio ou de outro tipo é rejeitado', () {
    for (final key in ['id', 'name', 'email', 'role']) {
      expect(
        () => AuthUser.fromJson({...json}..remove(key)),
        throwsFormatException,
        reason: 'sem $key',
      );
      expect(
        () => AuthUser.fromJson({...json, key: '  '}),
        throwsFormatException,
        reason: '$key vazio',
      );
      expect(
        () => AuthUser.fromJson({...json, key: 5}),
        throwsFormatException,
        reason: '$key numérico',
      );
    }
  });

  test('ida e volta em JSON preserva os dados', () {
    final user = AuthUser.fromJson(json);
    expect(AuthUser.fromJson(user.toJson()), user);
  });

  test('firstName pega só o primeiro nome', () {
    expect(AuthUser.fromJson(json).firstName, 'Ana');
    expect(AuthUser.fromJson({...json, 'name': '  Maria   Clara '}).firstName, 'Maria');
    expect(AuthUser.fromJson({...json, 'name': 'Cher'}).firstName, 'Cher');
  });
}
