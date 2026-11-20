import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/user_models.dart';

/// Cartão de um usuário na lista: nome, perfil, situação e, quando a API
/// informa, se há tag NFC e rosto vinculados.
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.onTap});

  final UserSummary user;
  final VoidCallback onTap;

  /// Frase única lida por leitores de tela.
  String get semanticLabel {
    final parts = <String>[
      user.name,
      user.role.label,
      user.active ? 'ativo' : 'inativo',
      if (user.hasNfcTag != null)
        user.hasNfcTag! ? 'com tag NFC' : 'sem tag NFC',
      if (user.hasFace != null) user.hasFace! ? 'com rosto' : 'sem rosto',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final contact = [
      user.email,
      if (user.document != null) 'Doc. ${user.document}',
    ].join('  |  ');

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      user.active ? AppColors.primary : AppColors.textSecondary,
                  child: Text(
                    user.name.trim().isEmpty
                        ? '?'
                        : user.name.trim().substring(0, 1).toUpperCase(),
                    style: theme.titleMedium?.copyWith(
                      color: AppColors.onDark,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        contact,
                        style: theme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(label: user.role.label, icon: Icons.badge),
                          _Badge(
                            label: user.active ? 'Ativo' : 'Inativo',
                            icon: user.active
                                ? Icons.check_circle_outline
                                : Icons.block,
                            highlight: !user.active,
                          ),
                          if (user.hasNfcTag != null)
                            _Badge(
                              label: user.hasNfcTag!
                                  ? 'Com tag NFC'
                                  : 'Sem tag NFC',
                              icon: Icons.nfc,
                            ),
                          if (user.hasFace != null)
                            _Badge(
                              label: user.hasFace! ? 'Com rosto' : 'Sem rosto',
                              icon: Icons.face,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const ExcludeSemantics(
                  child: Icon(Icons.chevron_right, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, this.highlight = false});

  final String label;
  final IconData icon;

  /// Usado para "Inativo": borda e ícone na cor de destaque.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.accent : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
