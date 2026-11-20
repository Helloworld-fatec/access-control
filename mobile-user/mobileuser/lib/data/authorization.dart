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
  final String id, place, period, timeWindow;
  final int? remainingUses;
  final AuthorizationStatus status;
  String get usesLabel =>
      remainingUses == null ? 'Ilimitados' : remainingUses.toString();
  factory Authorization.fromJson(Map<String, dynamic> j) {
    final l = j['location'] as Map<String, dynamic>? ?? const {};
    final b = l['building'] as String? ?? 'Local';
    final d = [
      l['entrance'],
      l['door'],
      l['turnstile'],
    ].whereType<String>().where((x) => x.isNotEmpty).join(' / ');
    final sd = _date(j['startDate'] as String?),
        ed = _date(j['endDate'] as String?);
    final st = j['status'] == 'CANCELED'
        ? AuthorizationStatus.cancelled
        : j['status'] == 'ACTIVE'
        ? AuthorizationStatus.active
        : AuthorizationStatus.expired;
    final rem = j['remainingUses'];
    return Authorization(
      id: j['id'] as String? ?? '',
      place: d.isEmpty ? b : '$b - $d',
      period: sd == ed ? sd : sd + ' a ' + ed,
      timeWindow:
          (j['startTime'] as String? ?? '--:--') +
          ' as ' +
          (j['endTime'] as String? ?? '--:--'),
      remainingUses: rem is int ? rem : null,
      status: st,
    );
  }
  static String _date(String? s) {
    if (s == null || s.length < 10) return '--/--/----';
    final p = s.substring(0, 10).split('-');
    return p[2] + '/' + p[1] + '/' + p[0];
  }
}
