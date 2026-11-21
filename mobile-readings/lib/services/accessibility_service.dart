// ignore_for_file: deprecated_member_use

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Serviço de acessibilidade auditiva e feedback tátil para leitores de tela e pessoas com deficiência visual (US-20).
class AccessibilityService {
  final bool enabled;

  const AccessibilityService({this.enabled = true});

  /// Anuncia a liberação de acesso com áudio falado e vibração de confirmação.
  Future<void> notifyAccessGranted(String? userName) async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (_) {}

    final name = (userName != null && userName.isNotEmpty) ? userName : 'Usuário';
    final msg = 'Acesso liberado para $name. Pode passar pela catraca.';
    SemanticsService.announce(msg, TextDirection.ltr);
  }

  /// Anuncia a negação ou indisponibilidade de acesso com áudio e vibração de alerta.
  Future<void> notifyAccessDenied(String? reason) async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    final detail = (reason != null && reason.isNotEmpty)
        ? reason
        : 'Credencial não autorizada.';
    final msg = 'Atenção: Acesso negado. Motivo: $detail.';
    SemanticsService.announce(msg, TextDirection.ltr);
  }

  /// Anuncia detecção de presença ou ativação do terminal.
  Future<void> notifyTerminalAwake() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
    SemanticsService.announce(
      'Terminal ativado. Aponte para o QR Code ou olhe para a câmera frontal.',
      TextDirection.ltr,
    );
  }

  /// Alerta sobre iluminação insuficiente no leitor facial (US-19).
  Future<void> notifyLowLightWarning() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
    SemanticsService.announce(
      'Aviso: Iluminação insuficiente. Aproxime-se de uma fonte de luz.',
      TextDirection.ltr,
    );
  }

  /// Alerta sobre leitor ocupado gravando tag (US-10).
  Future<void> notifyReaderBusy(bool isBusy) async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
    if (isBusy) {
      SemanticsService.announce(
        'Leitor de cartão ocupado gravando tag remota. Aguarde um instante.',
        TextDirection.ltr,
      );
    } else {
      SemanticsService.announce(
        'Leitor de cartão liberado para leitura.',
        TextDirection.ltr,
      );
    }
  }
}
