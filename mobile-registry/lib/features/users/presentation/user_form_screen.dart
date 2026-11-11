import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_message.dart';
import '../../auth/application/auth_providers.dart';
import '../../nfc/presentation/nfc_capture_dialog.dart';
import '../application/users_list_controller.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';
import 'form_notice.dart';
import 'user_credentials_section.dart';
import 'user_data_fields.dart';
import 'user_form_model.dart';

/// Edição de um usuário (US-09), com ativação e desativação (US-10) e gestão
/// das tags NFC (US-12). O cadastro novo é o assistente `NewUserWizardScreen`.
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _model = UserFormModel();
  bool _showPassword = false;

  UserDetail? _detail;
  bool _loadingDetail = true;
  String? _loadError;

  bool _saving = false;
  bool _changingStatus = false;
  bool _tagBusy = false;

  /// Aviso do formulário e da situação.
  FormNotice? _notice;

  /// Aviso das tags (aparece junto da seção, que fica mais abaixo na tela).
  FormNotice? _tagNotice;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- carregar

  Future<void> _loadDetail() async {
    try {
      final detail = await ref.read(usersRepositoryProvider).get(widget.userId);
      if (!mounted) return;
      _model.fill(detail.user);
      setState(() {
        _detail = detail;
        _loadingDetail = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _loadError = userMessageFor(e);
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loadingDetail = true;
      _loadError = null;
    });
    unawaited(_loadDetail());
  }

  // ----------------------------------------------------------------- salvar

  Future<void> _submit() async {
    // Os erros apontados pelo backend só saem quando o usuário edita o
    // campo: o servidor recusou aquele valor.
    setState(() => _notice = null);
    if (!_model.formKey.currentState!.validate()) {
      setState(() {
        _notice = const FormNotice(StatusKind.error, FormNotice.checkFields);
      });
      return;
    }
    FocusScope.of(context).unfocus();
    await _saveEdit();
  }

  Future<void> _saveEdit() async {
    final changes = _model.changesFrom(_detail!.user);
    if (changes.isEmpty) {
      setState(() {
        _notice = const FormNotice(
          StatusKind.info,
          'Nenhuma alteração para salvar.',
        );
      });
      return;
    }

    // Alterações só são salvas após confirmação (US-09).
    final confirmed = await showConfirmDialog(
      context,
      title: 'Salvar as alterações?',
      message: 'Os dados de ${_detail!.user.name} serão atualizados.',
      confirmLabel: 'Salvar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(usersRepositoryProvider).update(widget.userId, changes);
      _refreshList();
      if (!mounted) return;
      _showMessage('Alterações salvas.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final outcome = _model.applyApiError(ApiException.from(e));
      setState(() {
        _saving = false;
        _notice = FormNotice(StatusKind.error, outcome.message);
      });
      // Faz os erros apontados pelo backend aparecerem sob os campos.
      _model.formKey.currentState?.validate();
    }
  }

  void _refreshList() => unawaited(ref.read(usersListProvider.notifier).refresh());

  /// Mostra uma mensagem rápida, substituindo a anterior (sem formar fila).
  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------- ativar/desativar

  Future<void> _changeStatus({required bool activate}) async {
    final user = _detail!.user;

    if (!activate) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Desativar ${user.name}?',
        message: 'O usuário deixará de ter acesso. O histórico de acessos '
            'é preservado e você pode reativá-lo quando quiser.',
        confirmLabel: 'Desativar',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _changingStatus = true;
      _notice = null;
    });
    try {
      final updated = await ref
          .read(usersRepositoryProvider)
          .setActive(user.id, active: activate);
      _refreshList();
      if (!mounted) return;
      setState(() {
        _detail = _detail!.withUser(updated);
        _changingStatus = false;
      });
      _showMessage(activate ? 'Usuário reativado.' : 'Usuário desativado.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _changingStatus = false;
        _notice = FormNotice(StatusKind.error, userMessageFor(e));
      });
    }
  }

  // --------------------------------------------------------------- tags NFC

  /// Roda uma operação de tag com bloqueio de botões e tratamento de erro.
  Future<void> _runTagAction(Future<void> Function() action) async {
    setState(() {
      _tagBusy = true;
      _tagNotice = null;
    });
    try {
      await action();
      _refreshList();
    } catch (e) {
      if (!mounted) return;
      setState(() => _tagNotice = FormNotice(StatusKind.error, userMessageFor(e)));
    } finally {
      if (mounted) setState(() => _tagBusy = false);
    }
  }

  void _tagInfo(String message) {
    setState(() => _tagNotice = FormNotice(StatusKind.info, message));
  }

  Future<void> _linkTag() async {
    final uid = await showNfcCaptureDialog(context, title: 'Vincular tag NFC');
    if (uid == null || !mounted) return;
    if (_detail!.nfcTags.any((t) => t.uid == uid)) {
      _tagInfo('Esta tag já está vinculada a este usuário.');
      return;
    }
    await _runTagAction(() async {
      final tag = await ref.read(usersRepositoryProvider).addTag(widget.userId, uid);
      if (!mounted) return;
      setState(() => _detail = _detail!.withTags([..._detail!.nfcTags, tag]));
      _showMessage('Tag vinculada.');
    });
  }

  Future<void> _replaceTag(NfcTag old) async {
    final uid = await showNfcCaptureDialog(
      context,
      title: 'Substituir tag NFC',
      instruction: 'Aproxime a NOVA tag da parte de trás do celular e espere '
          'um instante.',
      confirmLabel: 'Usar a nova tag',
    );
    if (uid == null || !mounted) return;

    if (uid == old.uid) {
      _tagInfo('Esta já é a tag atual deste usuário.');
      return;
    }
    if (_detail!.nfcTags.any((t) => t.uid == uid)) {
      _tagInfo('Esta tag já está vinculada a este usuário.');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Substituir a tag?',
      message: 'A tag ${old.uid} deixará de funcionar e a tag $uid passará '
          'a valer para ${_detail!.user.name}.',
      confirmLabel: 'Substituir',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _runTagAction(() async {
      final result = await ref.read(usersRepositoryProvider).replaceTag(
            userId: widget.userId,
            oldTagId: old.id,
            newUid: uid,
          );
      if (!mounted) return;
      final tags = [
        for (final t in _detail!.nfcTags)
          if (t.id != old.id || !result.oldTagRemoved) t,
        result.added,
      ];
      setState(() {
        _detail = _detail!.withTags(tags);
        if (!result.oldTagRemoved) {
          _tagNotice = FormNotice(
            StatusKind.error,
            'A nova tag foi vinculada, mas não foi possível remover a antiga '
            '(${result.removeError!.message}). Remova a tag antiga '
            'manualmente.',
          );
        }
      });
      if (result.oldTagRemoved) _showMessage('Tag substituída.');
    });
  }

  Future<void> _removeTag(NfcTag tag) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover a tag?',
      message: 'A tag ${tag.uid} será desvinculada de ${_detail!.user.name}. '
          'A pessoa deixará de entrar com ela.',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _runTagAction(() async {
      await ref.read(usersRepositoryProvider).removeTag(widget.userId, tag.id);
      if (!mounted) return;
      setState(() {
        _detail = _detail!.withTags([
          for (final t in _detail!.nfcTags)
            if (t.id != tag.id) t,
        ]);
      });
      _showMessage('Tag removida.');
    });
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar usuário')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loadingDetail) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Carregando usuário',
          child: const CircularProgressIndicator(strokeWidth: 4),
        ),
      );
    }
    if (_loadError != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusMessage(kind: StatusKind.error, message: _loadError!),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'Tentar novamente',
              icon: Icons.refresh,
              onPressed: _retryLoad,
            ),
          ],
        ),
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    final detail = _detail!;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _model.formKey,
            child: UserDataFields(
              model: _model,
              isEdit: true,
              original: detail.user,
              readOnly: _saving,
              showPassword: _showPassword,
              onShowPasswordChanged: (v) => setState(() => _showPassword = v),
            ),
          ),
          const SizedBox(height: 16),
          if (_notice != null) ...[
            StatusMessage(kind: _notice!.kind, message: _notice!.message),
            const SizedBox(height: 16),
          ],
          AppPrimaryButton(
            label: 'Salvar alterações',
            icon: Icons.save,
            isLoading: _saving,
            onPressed: (_changingStatus || _tagBusy) ? null : _submit,
          ),
          const SizedBox(height: 32),
          _StatusSection(
            detail: detail,
            isSelf: ref.watch(authProvider).user?.id == detail.user.id,
            busy: _changingStatus,
            onChange: (activate) => _changeStatus(activate: activate),
          ),
          const SizedBox(height: 24),
          UserCredentialsSection(
            detail: detail,
            busy: _tagBusy,
            notice: _tagNotice?.message,
            noticeKind: _tagNotice?.kind ?? StatusKind.error,
            onLink: _linkTag,
            onReplace: _replaceTag,
            onRemove: _removeTag,
          ),
        ],
      ),
    );
  }
}

/// Situação do usuário e botão de ativar/desativar (US-10).
class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.detail,
    required this.isSelf,
    required this.busy,
    required this.onChange,
  });

  final UserDetail detail;
  final bool isSelf;
  final bool busy;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final active = detail.user.active;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Situação', style: theme.titleLarge),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    active ? Icons.check_circle_outline : Icons.block,
                    color: active ? AppColors.primary : AppColors.accent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    active
                        ? 'Usuário ativo. Pode acessar normalmente.'
                        : 'Usuário inativo. Não tem acesso, mas o histórico foi preservado.',
                    style: theme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (active && isSelf)
          Text(
            'Você não pode desativar a própria conta.',
            style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          )
        else if (active)
          AppSecondaryButton(
            label: 'Desativar usuário',
            icon: Icons.block,
            isLoading: busy,
            onPressed: () => onChange(false),
          )
        else
          AppPrimaryButton(
            label: 'Reativar usuário',
            icon: Icons.restore,
            isLoading: busy,
            onPressed: () => onChange(true),
          ),
      ],
    );
  }
}
