import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_readings/services/nfc_service.dart';

void main() {
  group('NfcUidHelper (US-09)', () {
    test('converte bytes do UID para hexadecimal maiúsculo na mesma ordem', () {
      final bytes = [0x04, 0x0a, 0xb1, 0xff, 0x00, 0x7c, 0x80];
      expect(NfcUidHelper.formatUidBytes(bytes), equals('040AB1FF007C80'));
    });

    test('normaliza string com separadores para hexadecimal maiúsculo', () {
      expect(
        NfcUidHelper.normalizeHexUid('04:a1:b2:c3'),
        equals('04A1B2C3'),
      );
      expect(
        NfcUidHelper.normalizeHexUid('04-a1-b2-c3-d4-e5-f6'),
        equals('04A1B2C3D4E5F6'),
      );
    });

    test('rejeita UID fora do tamanho válido (4 a 16 bytes)', () {
      expect(
        () => NfcUidHelper.normalizeHexUid('04A1'),
        throwsFormatException,
      );
      expect(
        () => NfcUidHelper.normalizeHexUid('04A1B'),
        throwsFormatException,
      );
    });
  });

  group('NfcCooldownGuard (US-10)', () {
    test('bloqueia leituras repetidas dentro do intervalo mínimo', () {
      final guard = NfcCooldownGuard(minInterval: const Duration(seconds: 3));
      final t0 = DateTime(2026, 10, 15, 12, 0, 0);

      expect(guard.shouldAccept('04A1B2C3', now: t0), isTrue);
      expect(
        guard.shouldAccept(
          '04A1B2C3',
          now: t0.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        guard.shouldAccept(
          '04A1B2C3',
          now: t0.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
    });
  });
}
