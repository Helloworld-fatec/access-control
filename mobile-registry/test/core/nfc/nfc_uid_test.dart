import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/nfc/nfc_uid.dart';

void main() {
  group('formatBytes', () {
    test('hexadecimal maiúsculo, mesma ordem de bytes', () {
      expect(NfcUid.formatBytes([0x04, 0xA3, 0x2F, 0x1B]), '04A32F1B');
      expect(NfcUid.formatBytes([0x1B, 0x2F, 0xA3, 0x04]), '1B2FA304');
    });

    test('completa com zero à esquerda', () {
      expect(NfcUid.formatBytes([0, 1, 10, 255]), '00010AFF');
    });

    test('7 bytes (tags comuns) viram 14 caracteres', () {
      expect(
        NfcUid.formatBytes([0x04, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66]),
        '04112233445566',
      );
    });

    test('lista vazia é erro', () {
      expect(() => NfcUid.formatBytes([]), throwsArgumentError);
    });
  });

  group('normalize', () {
    test('aceita separadores comuns e minúsculas', () {
      for (final raw in ['04:a3:2f:1b', '04 a3 2f 1b', '04-A3-2F-1B', '04a32f1b', ' 04A32F1B ']) {
        expect(NfcUid.normalize(raw), '04A32F1B', reason: raw);
      }
    });

    test('rejeita o que não é UID', () {
      for (final raw in [
        '',
        'XYZ12345',
        '04A3', // curto
        '04A32F1B04A32F1B04A32F', // longo (22)
        '04A32F1B0', // número ímpar de dígitos
        '04A3 2F1G', // letra fora de A-F
      ]) {
        expect(() => NfcUid.normalize(raw), throwsFormatException, reason: raw);
      }
    });

    test('tryNormalize devolve null em vez de lançar', () {
      expect(NfcUid.tryNormalize('04:a3:2f:1b'), '04A32F1B');
      expect(NfcUid.tryNormalize('xyz'), isNull);
    });
  });

  group('isValid (limites do backend: 8 a 20, par)', () {
    test('limites', () {
      expect(NfcUid.isValid('0' * 8), isTrue);
      expect(NfcUid.isValid('A' * 20), isTrue);
      expect(NfcUid.isValid('0' * 6), isFalse);
      expect(NfcUid.isValid('0' * 22), isFalse);
      expect(NfcUid.isValid('0' * 9), isFalse);
    });

    test('só hexadecimal maiúsculo', () {
      expect(NfcUid.isValid('04a32f1b'), isFalse);
      expect(NfcUid.isValid('04G32F1B'), isFalse);
    });
  });

  group('extractIdentifier', () {
    test('lê o identificador da tecnologia da tag', () {
      expect(
        NfcUid.extractIdentifier({'nfca': {'identifier': [4, 163, 47, 27]}}),
        [4, 163, 47, 27],
      );
      expect(
        NfcUid.extractIdentifier({'mifareclassic': {'identifier': [1, 2, 3, 4]}}),
        [1, 2, 3, 4],
      );
    });

    test('aceita identificador na raiz', () {
      expect(NfcUid.extractIdentifier({'identifier': [9, 8, 7, 6]}), [9, 8, 7, 6]);
    });

    test('sem identificador, devolve null', () {
      expect(NfcUid.extractIdentifier({}), isNull);
      expect(NfcUid.extractIdentifier({'nfca': {'atqa': [1]}}), isNull);
    });
  });
}
