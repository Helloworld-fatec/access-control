import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Card de apoio com título e valor, lido como uma única frase por leitores de tela.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$title: $value',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: theme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
