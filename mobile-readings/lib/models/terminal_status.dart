/// Status do terminal retornado por GET /terminals/{id}/status (US-06).
class TerminalStatus {
  final bool online;
  final bool presenceActive;
  final DateTime? lastPresenceAt;

  const TerminalStatus({
    required this.online,
    required this.presenceActive,
    this.lastPresenceAt,
  });

  factory TerminalStatus.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final current = now ?? DateTime.now();
    DateTime? lastPresence;
    if (json['lastPresenceAt'] != null) {
      lastPresence = DateTime.tryParse(json['lastPresenceAt'].toString());
    }

    final explicitPresence =
        json['presence'] == true || json['presenceActive'] == true;
    final recentPresence = lastPresence != null &&
        current.difference(lastPresence).inSeconds.abs() <= 5;

    return TerminalStatus(
      online: json['online'] == true,
      presenceActive: explicitPresence || recentPresence,
      lastPresenceAt: lastPresence,
    );
  }
}
