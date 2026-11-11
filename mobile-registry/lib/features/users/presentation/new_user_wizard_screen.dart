import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_message.dart';
import '../../nfc/presentation/nfc_capture_dialog.dart';
import '../application/users_list_controller.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';
import 'form_notice.dart';
import 'user_data_fields.dart';
import 'user_form_model.dart';
import 'wizard_progress.dart';
import 'wizard_steps.dart';

/// Cadastro de usuário em assistente por etapas (US-07):
/// 1) dados, 2) tag NFC (opcional), 3) rosto (opcional), 4) revisão.
///
/// O usuário é enviado primeiro (`POST /users`) e os vínculos em seguida,
/// para não perder o cadastro inteiro se uma etapa falhar.
class NewUserWizardScreen extends ConsumerStatefulWidget {
  const NewUserWizardScreen({super.key});

  @override
  ConsumerState<NewUserWizardScreen> createState() =>
      _NewUserWizardScreenState();
}

class _NewUserWizardScreenState extends ConsumerState<NewUserWizardScreen> {
  static const List<String> _titles = ['Dados', 'Tag NFC', 'Rosto', 'Revisão'];
  static const int _last = 3;

  final _model = UserFormModel();

  int _step = 0;
  String? _tagUid;
  bool _showPassword = false;
  bool _saving = false;
  FormNotice? _notice;

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- navegação

  void _goTo(int step) {
    setState(() {
      _step = step;
      _notice = null;
    });
  }

  void _next() {
    if (_step == 0) {
      if (!_model.formKey.currentState!.validate()) {
        setState(() {
          _notice = const FormNotice(StatusKind.error, FormNotice.checkFields);
        });
        return;
      }
      FocusScope.of(context).unfocus();
    }
    _goTo(_step + 1);
  }

  void _back() => _goTo(_step - 1);

  Future<void> _readTag() async {
    final uid = await showNfcCaptureDialog(context, title: 'Ler tag NFC');
    if (uid == null || !mounted) return;
    setState(() => _tagUid = uid);
  }

  // -------------------------------------------------------------- confirmar

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _notice = null;
    });
    final repo = ref.read(usersRepositoryProvider);

    // 1) o usuário primeiro
    final UserSummary created;
    try {
      created = await repo.create(_model.toNewUser());
    } catch (e) {
      _onCreateError(e);
      return;
    }

    // 2) os vínculos em seguida: uma falha aqui NÃO desfaz o cadastro
    String? tagProblem;
    final uid = _tagUid;
    if (uid != null) {
      try {
        await repo.addTag(created.id, uid);
      } catch (e) {
        tagProblem = userMessageFor(e);
      }
    }

    unawaited(ref.read(usersListProvider.notifier).refresh());
    if (!mounted) return;

    if (tagProblem == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Usuário cadastrado.')));
      context.pop();
      return;
    }

    setState(() => _saving = false);
    final openRegistration = await showConfirmDialog(
      context,
      title: 'Usuário cadastrado',
      message: 'O cadastro foi feito, mas a tag NFC não foi vinculada: '
          '$tagProblem\n\nVocê pode vincular a tag depois, pela edição do '
          'usuário.',
      confirmLabel: 'Abrir cadastro',
      cancelLabel: 'Fechar',
    );
    if (!mounted) return;
    if (openRegistration) {
      context.pushReplacement(AppRoutes.userDetail(created.id));
    } else {
      context.pop();
    }
  }

  void _onCreateError(Object error) {
    if (!mounted) return;
    final outcome = _model.applyApiError(ApiException.from(error));
    setState(() {
      _saving = false;
      _notice = FormNotice(StatusKind.error, outcome.message);
      // Erro nos dados (campo inválido, e-mail ou documento repetido): volta
      // à primeira etapa, onde o campo é corrigido.
      if (outcome.fieldsAffected) _step = 0;
    });
    if (outcome.fieldsAffected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _model.formKey.currentState?.validate();
      });
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Na primeira etapa, voltar sai do assistente; nas demais, volta uma etapa.
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _step > 0) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Novo usuário')),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WizardProgress(step: _step, titles: _titles),
                const SizedBox(height: 24),
                _stepContent(),
                const SizedBox(height: 16),
                if (_notice != null) ...[
                  StatusMessage(kind: _notice!.kind, message: _notice!.message),
                  const SizedBox(height: 16),
                ],
                ..._navigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return Form(
          key: _model.formKey,
          child: UserDataFields(
            model: _model,
            isEdit: false,
            readOnly: _saving,
            showPassword: _showPassword,
            onShowPasswordChanged: (v) => setState(() => _showPassword = v),
          ),
        );
      case 1:
        return TagStep(
          uid: _tagUid,
          onRead: _readTag,
          onClear: () => setState(() => _tagUid = null),
        );
      case 2:
        return const FaceStep();
      default:
        return ReviewStep(model: _model, tagUid: _tagUid);
    }
  }

  List<Widget> _navigation() {
    const gap = SizedBox(height: 12);
    switch (_step) {
      case 0:
        return [
          AppPrimaryButton(
            label: 'Avançar',
            icon: Icons.arrow_forward,
            onPressed: _next,
          ),
          gap,
          AppSecondaryButton(
            label: 'Cancelar',
            icon: Icons.close,
            onPressed: () => context.pop(),
          ),
        ];
      case _last:
        return [
          AppPrimaryButton(
            label: 'Confirmar cadastro',
            icon: Icons.check,
            isLoading: _saving,
            onPressed: _confirm,
          ),
          gap,
          AppSecondaryButton(
            label: 'Voltar',
            icon: Icons.arrow_back,
            onPressed: _saving ? null : _back,
          ),
        ];
      default:
        return [
          AppPrimaryButton(
            label: (_step == 1 && _tagUid == null)
                ? 'Pular esta etapa'
                : 'Avançar',
            icon: Icons.arrow_forward,
            onPressed: _next,
          ),
          gap,
          AppSecondaryButton(
            label: 'Voltar',
            icon: Icons.arrow_back,
            onPressed: _back,
          ),
        ];
    }
  }
}
