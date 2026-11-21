class QrToken {
  final Map<String, dynamic> payload;
  final DateTime expiresAt;
  final int refreshAfterSeconds;

  const QrToken({
    required this.payload,
    required this.expiresAt,
    required this.refreshAfterSeconds,
  });

  factory QrToken.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final expiresAt = json['expiresAt'];
    final refreshAfter = json['refreshAfterSeconds'];
    if (payload is! Map<String, dynamic> ||
        payload['v'] != 1 ||
        payload['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(payload['token'] as String) ||
        expiresAt is! String ||
        refreshAfter is! int ||
        refreshAfter <= 0) {
      throw const FormatException('Formato do QR Code incompatível.');
    }
    return QrToken(
      payload: Map.unmodifiable(payload),
      expiresAt: DateTime.parse(expiresAt),
      refreshAfterSeconds: refreshAfter,
    );
  }
}
