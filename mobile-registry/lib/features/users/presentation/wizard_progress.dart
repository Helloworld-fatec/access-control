import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Indicador de progresso do assistente: "Etapa 2 de 4", barra e as etapas
/// numeradas (as concluídas mostram um visto). Lido por leitores de tela como
/// uma frase só.
class WizardProgress extends StatelessWidget {
  const WizardProgress({super.key, required this.step, required this.titles});

  /// Etapa atual, começando em 0.
  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = titles.length;

    return Semantics(
      container: true,
      label: 'Etapa ${step + 1} de $total: ${titles[step]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Etapa ${step + 1} de $total',
              style: theme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(titles[step], style: theme.titleLarge),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (step + 1) / total,
                minHeight: 10,
                color: AppColors.primary,
                backgroundColor: AppColors.support,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: _StepDot(
                      number: i + 1,
                      label: titles[i],
                      done: i < step,
                      current: i == step,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
  });

  final int number;
  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final filled = done || current;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : AppColors.support,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 20, color: AppColors.onDark)
              : Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: filled ? AppColors.onDark : AppColors.textPrimary,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
              ),
        ),
      ],
    );
  }
}
