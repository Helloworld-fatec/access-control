import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StatusKind { success, error }

/// Mensagem de resultado com ícone + texto (nunca depende só da cor)
/// e anunciada por leitores de tela (liveRegion).
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.kind, required this.message});

  final StatusKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isError = kind == StatusKind.error;
    final color = isError ? AppColors.accent : AppColors.primary;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${isError ? 'Erro' : 'Sucesso'}: $message',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.support,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
