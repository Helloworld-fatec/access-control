import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo de confirmação com botões grandes. Devolve `true` se o usuário
/// confirmar. Com [destructive], o botão de confirmação usa a cor de destaque.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          // Tamanho próprio: o tema dos botões é "largura total", que não
          // cabe na linha de ações do diálogo.
          style: FilledButton.styleFrom(
            minimumSize: const Size(120, 56),
            backgroundColor:
                destructive ? AppColors.accent : AppColors.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
