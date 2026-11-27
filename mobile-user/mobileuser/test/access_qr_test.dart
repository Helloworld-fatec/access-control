import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileuser/features/qr/access_qr.dart';

void main() {
  test('extrai o token do OLED e o token do celular', () {
    const oled = 'Q123456789ABCDEFGHIJ';
    final mobile = List.filled(43, 'a').join();
    expect(accessQrToken(oled), oled);
    expect(accessQrToken(jsonEncode({'v': 1, 'token': mobile})), mobile);
    expect(accessQrToken(oled.toLowerCase()), isNull);
    expect(accessQrToken('$oled\n'), isNull);
    expect(accessQrToken(jsonEncode({'v': 2, 'token': mobile})), isNull);
    expect(accessQrToken(mobile), isNull);
  });
}
