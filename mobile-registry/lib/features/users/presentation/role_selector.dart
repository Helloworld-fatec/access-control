import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/user_models.dart';

/// Escolha do perfil com botões grandes (sem lista suspensa, mais fácil de
/// tocar). Integra-se ao `Form` para validação.
class RoleSelector extends FormField<UserRole> {
  RoleSelector({
    super.key,
    super.initialValue,
    super.validator,
    super.enabled,
    ValueChanged<UserRole?>? onChanged,
  }) : super(
          builder: (state) {
            final context = state.context;
            final enabled = state.widget.enabled;
            final theme = Theme.of(context).textTheme;
            return Semantics(
              container: true,
              label: 'Perfil. Selecionado: ${state.value?.label ?? 'nenhum'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfil',
                    style: theme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final role in UserRole.values)
                        ChoiceChip(
                          label: Text(role.label),
                          selected: state.value == role,
                          showCheckmark: true,
                          checkmarkColor: AppColors.onDark,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.support,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          labelStyle: theme.bodyLarge?.copyWith(
                            color: state.value == role
                                ? AppColors.onDark
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          onSelected: enabled
                              ? (_) {
                                  state.didChange(role);
                                  onChanged?.call(role);
                                }
                              : null,
                        ),
                    ],
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.errorText!,
                      style: theme.bodyMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
}
