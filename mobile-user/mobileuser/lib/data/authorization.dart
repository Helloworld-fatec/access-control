enum AuthorizationStatus { active, expired, cancelled }

class Authorization {
  const Authorization({
    required this.id,
    required this.place,
    required this.period,
    required this.timeWindow,
    required this.remainingUses,
    required this.status,
  });

  final String id;
  final String place;
  final String period;
  final String timeWindow;

  /// null = ilimitado
  final int? remainingUses;
  final AuthorizationStatus status;

  String get usesLabel =>
      remainingUses == null ? 'Ilimitados' : '$remainingUses';
}
