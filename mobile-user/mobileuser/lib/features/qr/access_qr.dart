import 'dart:convert';

final _oledToken = RegExp(r'^Q[A-Z0-9]{19}$');
final _mobileToken = RegExp(r'^[A-Za-z0-9_-]{43}$');

String? accessQrToken(String raw) {
  if (_oledToken.hasMatch(raw) && raw.length == 20) return raw;

  try {
    final parsed = jsonDecode(raw);
    if (parsed is! Map || parsed['v'] != 1) return null;
    final token = parsed['token'];
    return token is String && token.length == 43 && _mobileToken.hasMatch(token)
        ? token
        : null;
  } on FormatException {
    return null;
  }
}
