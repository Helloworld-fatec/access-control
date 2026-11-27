/// Decisão retornada pelo backend após validação da credencial (US-10, US-11, US-12).
enum AccessDecision {
  granted,
  denied,
  unavailable,
}

/// Resultado de uma tentativa facial.
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

  factory AccessResult.unavailable([String? detail]) {
    return AccessResult(
      decision: AccessDecision.unavailable,
      message: detail ?? 'Sistema indisponível no momento. Tente novamente.',
      reasonCode: 'NETWORK_UNAVAILABLE',
    );
  }
}
