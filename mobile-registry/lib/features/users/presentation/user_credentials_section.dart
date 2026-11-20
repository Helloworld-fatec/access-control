import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_message.dart';
import '../data/user_models.dart';

/// Tag NFC e rosto do usuário, na tela de edição. Permite vincular, substituir
/// e remover tags NFC (US-12). O cadastro do rosto chega nas próximas etapas.
class UserCredentialsSection extends StatelessWidget {
  const UserCredentialsSection({
    super.key,
    required this.detail,
    required this.busy,
    required this.onLink,
    required this.onReplace,
    required this.onRemove,
    this.notice,
    this.noticeKind = StatusKind.error,
  });

  final UserDetail detail;

  /// Há uma operação de tag em andamento: bloqueia os botões.
  final bool busy;
  final VoidCallback onLink;
  final ValueChanged<NfcTag> onReplace;
  final ValueChanged<NfcTag> onRemove;

  /// Resultado da última operação de tag (aparece junto da seção).
  final String? notice;
  final StatusKind noticeKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final tags = detail.nfcTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Tag NFC e rosto', style: theme.titleLarge),
        ),
        const SizedBox(height: 12),
        if (notice != null) ...[
          StatusMessage(kind: noticeKind, message: notice!),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Row(
                  icon: Icons.nfc,
                  text: tags.isEmpty
                      ? 'Nenhuma tag NFC vinculada.'
                      : tags.length == 1
                          ? 'Tag NFC vinculada:'
                          : '${tags.length} tags NFC vinculadas:',
                ),
                for (final tag in tags) ...[
                  const SizedBox(height: 12),
                  _TagTile(
                    tag: tag,
                    busy: busy,
                    onReplace: () => onReplace(tag),
                    onRemove: () => onRemove(tag),
                  ),
                ],
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: tags.isEmpty ? 'Vincular tag NFC' : 'Vincular outra tag NFC',
                  icon: Icons.add,
                  isLoading: busy,
                  onPressed: onLink,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(
                  icon: Icons.face,
                  text: detail.hasFace
                      ? 'Rosto cadastrado.'
                      : 'Rosto não cadastrado.',
                ),
                const SizedBox(height: 12),
                Text(
                  'O cadastro do rosto será liberado nas próximas etapas do '
                  'aplicativo.',
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
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

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.busy,
    required this.onReplace,
    required this.onRemove,
  });

  final NfcTag tag;
  final bool busy;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'Tag NFC ${tag.uid}${tag.active ? '' : ', inativa'}',
            child: ExcludeSemantics(
              child: Text(
                tag.active ? tag.uid : '${tag.uid} (inativa)',
                style: theme.titleMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Substituir',
            icon: Icons.swap_horiz,
            onPressed: busy ? null : onReplace,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
