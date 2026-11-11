import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/config/settings_validators.dart';

void main() {
  group('host (IPv4)', () {
    test('aceita IPs válidos', () {
      for (final ip in ['192.168.0.10', '10.0.2.2', '0.0.0.0', '255.255.255.255']) {
        expect(SettingsValidators.host(ip), isNull, reason: ip);
      }
    });

    test('ignora espaços nas pontas', () {
      expect(SettingsValidators.host('  192.168.0.10 '), isNull);
    });

    test('rejeita vazio com mensagem clara', () {
      expect(SettingsValidators.host(''), 'Informe o endereço do servidor.');
      expect(SettingsValidators.host(null), 'Informe o endereço do servidor.');
    });

    test('rejeita formatos inválidos', () {
      for (final ip in [
        '999.1.1.1',
        '192.168.0',
        '192.168.0.1.5',
        '192.168.0.',
        'a.b.c.d',
        'localhost',
        '192.168.0.-1',
        '1234.1.1.1',
      ]) {
        expect(
          SettingsValidators.host(ip),
          'Endereço inválido. Use o formato 192.168.0.10.',
          reason: ip,
        );
      }
    });
  });

  group('porta', () {
    test('aceita de 1 a 65535', () {
      for (final p in ['1', '3000', '65535']) {
        expect(SettingsValidators.port(p), isNull, reason: p);
      }
    });

    test('rejeita vazio, zero, acima do limite e não numérico', () {
      expect(SettingsValidators.port(''), 'Informe a porta do servidor.');
      for (final p in ['0', '65536', 'abc', '-1', '30.5']) {
        expect(
          SettingsValidators.port(p),
          'Porta inválida. Use um número de 1 a 65535.',
          reason: p,
        );
      }
    });
  });

  group('tamanho da foto', () {
    test('aceita de 10 a 500 KB', () {
      for (final p in ['10', '50', '500']) {
        expect(SettingsValidators.photoKb(p), isNull, reason: p);
      }
    });

    test('rejeita fora do intervalo', () {
      for (final p in ['', '9', '501', 'x']) {
        expect(SettingsValidators.photoKb(p), isNotNull, reason: p);
      }
    });
  });

  group('capturas do rosto', () {
    test('aceita 3, 4 e 5', () {
      for (final n in [3, 4, 5]) {
        expect(SettingsValidators.faceSamples(n), isNull);
      }
    });

    test('rejeita fora de 3 a 5', () {
      for (final n in [null, 0, 2, 6]) {
        expect(SettingsValidators.faceSamples(n), isNotNull);
      }
    });
  });
}
