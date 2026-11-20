import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botão principal: grande, com rótulo em texto e bloqueio contra toques
/// repetidos enquanto [isLoading] (indicador de carregamento em toda chamada de rede).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.onDark,
            )
          : null,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        spinnerColor: AppColors.onDark,
      ),
    );
  }
}

/// Botão secundário (contorno).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? OutlinedButton.styleFrom(
              disabledForegroundColor: AppColors.primary,
            )
          : null,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        spinnerColor: AppColors.primary,
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.spinnerColor,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final Color spinnerColor;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: spinnerColor,
              semanticsLabel: 'Carregando',
            ),
          )
        : (icon != null ? ExcludeSemantics(child: Icon(icon, size: 28)) : null);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 12)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}
