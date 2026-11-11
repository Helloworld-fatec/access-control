import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import 'user_form_model.dart';

/// Etapa 2: tag NFC (opcional). Lê a tag e guarda o UID; o vínculo só é feito
/// depois que o usuário é criado.
class TagStep extends StatelessWidget {
  const TagStep({
    super.key,
    required this.uid,
    required this.onRead,
    required this.onClear,
  });

  final String? uid;
  final VoidCallback onRead;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Tag NFC (opcional)', style: theme.titleLarge),
        ),
        const SizedBox(height: 12),
        Text(
          'Se a pessoa já tem uma tag, aproxime-a do celular para ler o '
          'código. Você pode pular esta etapa e vincular a tag depois, '
          'pela edição do usuário.',
          style: theme.bodyLarge,
        ),
        const SizedBox(height: 16),
        if (uid == null)
          AppPrimaryButton(
            label: 'Ler tag NFC',
            icon: Icons.nfc,
            onPressed: onRead,
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                container: true,
                label: 'Tag lida: $uid',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tag lida', style: theme.bodyMedium),
                            Text(
                              uid!,
                              style: theme.titleMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Ler outra tag',
            icon: Icons.nfc,
            onPressed: onRead,
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onClear, child: const Text('Não vincular tag')),
        ],
      ],
    );
  }
}

/// Etapa 3: rosto (opcional). A captura chega nas próximas etapas do app.
class FaceStep extends StatelessWidget {
  const FaceStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Rosto (opcional)', style: theme.titleLarge),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.face, color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'O cadastro do rosto será liberado nas próximas etapas do '
                    'aplicativo. Você poderá fazê-lo depois, pela edição do '
                    'usuário.',
                    style: theme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Etapa 4: revisão. Mostra tudo o que será enviado, para conferir.
class ReviewStep extends StatelessWidget {
  const ReviewStep({super.key, required this.model, required this.tagUid});

  final UserFormModel model;
  final String? tagUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    String optional(String text) => text.trim().isEmpty ? 'Não informado' : text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Confira os dados', style: theme.titleLarge),
        ),
        const SizedBox(height: 8),
        Text(
          'Se estiver tudo certo, confirme o cadastro. Para corrigir algo, '
          'volte às etapas anteriores.',
          style: theme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow('Nome', model.name.text.trim()),
                _SummaryRow('Documento', optional(model.document.text)),
                _SummaryRow('E-mail', model.email.text.trim()),
                _SummaryRow('Telefone', optional(model.phone.text)),
                _SummaryRow('Perfil', model.role?.label ?? 'Não escolhido'),
                const _SummaryRow('Senha', 'Definida (não é mostrada)'),
                _SummaryRow(
                  'Tag NFC',
                  tagUid ?? 'Nenhuma (vincule depois, pela edição)',
                ),
                const _SummaryRow(
                  'Rosto',
                  'Não cadastrado (faça depois, pela edição)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        container: true,
        label: '$label: $value',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(value, style: theme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
