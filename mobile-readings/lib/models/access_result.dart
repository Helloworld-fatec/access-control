/// Decisão retornada pelo backend após validação da credencial (US-10, US-11, US-12).
enum AccessDecision {
  granted,
  denied,
  unavailable,
}

/// Resultado de uma tentativa de acesso (NFC ou Facial).
class AccessResult {
  final AccessDecision decision;
  final String message;
  final String? reasonCode;
  final String? userName;

  const AccessResult({
    required this.decision,
    required this.message,
    this.reasonCode,
    this.userName,
  });

  bool get isGranted => decision == AccessDecision.granted;
  bool get isUnavailable => decision == AccessDecision.unavailable;

  factory AccessResult.fromJson(Map<String, dynamic> json) {
    final rawResult =
        (json['result'] ?? json['status'] ?? '').toString().toUpperCase();
    final allowed = json['allowed'] == true ||
        json['granted'] == true ||
        rawResult == 'GRANTED' ||
        rawResult == 'APPROVED' ||
        rawResult == 'ALLOWED';

    final reason = json['reason']?.toString();
    final message = json['message']?.toString() ??
        (allowed ? 'Acesso liberado' : _friendlyReason(reason));

    return AccessResult(
      decision: allowed ? AccessDecision.granted : AccessDecision.denied,
      message: message,
      reasonCode: reason,
      userName: json['userName']?.toString() ??
          (json['user'] is Map ? json['user']['name']?.toString() : null),
    );
  }

  factory AccessResult.unavailable([String? detail]) {
    return AccessResult(
      decision: AccessDecision.unavailable,
      message: detail ?? 'Sistema indisponível no momento. Tente novamente.',
      reasonCode: 'NETWORK_UNAVAILABLE',
    );
  }

  static String _friendlyReason(String? code) {
    switch (code?.toUpperCase()) {
      case 'TAG_NOT_FOUND':
      case 'INVALID_CREDENTIAL':
        return 'Credencial não cadastrada ou inválida.';
      case 'USER_INACTIVE':
        return 'Usuário inativo.';
      case 'NO_AUTHORIZATION':
      case 'UNAUTHORIZED':
        return 'Sem autorização ativa para este local.';
      case 'EXPIRED':
        return 'Autorização vencida.';
      case 'OUT_OF_SCHEDULE':
        return 'Fora do horário permitido.';
      case 'MAX_USES_REACHED':
        return 'Limite de acessos atingido.';
      default:
        return 'Acesso não autorizado.';
    }
  }
}
