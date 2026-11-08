/// Token do QR Code rotativo gerado pelo backend (US-07, US-08).
/// O terminal nunca cria nem interpreta o conteúdo do token: apenas renderiza.
class QrToken {
  final String token;
  final DateTime expiresAt;

  const QrToken({
    required this.token,
    required this.expiresAt,
  });

  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return !current.isBefore(expiresAt);
  }

  factory QrToken.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final rawToken =
        (json['token'] ?? json['qrToken'] ?? json['qr'] ?? '').toString();
    if (rawToken.isEmpty) {
      throw const FormatException('Token QR vazio na resposta do servidor.');
    }

    DateTime expiresAt;
    if (json['expiresAt'] != null) {
      expiresAt = DateTime.parse(json['expiresAt'].toString());
    } else if (json['ttlSeconds'] is num) {
      expiresAt = current.add(
        Duration(seconds: (json['ttlSeconds'] as num).toInt()),
      );
    } else {
      // Renovado a cada 10s (RF12); validade padrão de 12s para cobrir jitter de rede
      expiresAt = current.add(const Duration(seconds: 12));
    }

    return QrToken(
      token: rawToken,
      expiresAt: expiresAt,
    );
  }
}
