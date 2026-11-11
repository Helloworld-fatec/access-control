import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/auth_providers.dart';

/// Pergunta se o usuário quer mesmo sair e, se confirmar, encerra a sessão.
/// A confirmação evita saídas por toque acidental.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _LogoutDialog(),
  );
  if (confirmed != true) return;
  await ref.read(authProvider.notifier).signOut();
}

/// Ícone "Sair" para a barra superior das telas logadas.
class LogoutAppBarAction extends ConsumerWidget {
  const LogoutAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      iconSize: 28,
      tooltip: 'Sair',
      style: IconButton.styleFrom(
        foregroundColor: AppColors.onDark, // contraste sobre a barra azul
        minimumSize: const Size(56, 56),
      ),
      onPressed: () => confirmAndSignOut(context, ref),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sair do aplicativo?'),
      content: const Text(
        'Você precisará entrar novamente com seu e-mail e senha.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // Tamanho próprio: o tema dos botões é "largura total", que não
          // cabe na linha de ações do diálogo.
          style: FilledButton.styleFrom(
            minimumSize: const Size(120, 56),
            backgroundColor: AppColors.accent,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}
