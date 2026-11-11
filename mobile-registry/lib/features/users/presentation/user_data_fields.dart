import 'package:flutter/material.dart';

import '../data/user_models.dart';
import 'role_selector.dart';
import 'user_form_model.dart';
import 'user_form_validators.dart';

/// Campos de dados do usuário (US-08), usados no cadastro (etapa 1 do
/// assistente) e na edição. Deve ficar dentro de um `Form` com a chave de
/// [UserFormModel.formKey].
class UserDataFields extends StatelessWidget {
  const UserDataFields({
    super.key,
    required this.model,
    required this.isEdit,
    required this.readOnly,
    required this.showPassword,
    required this.onShowPasswordChanged,
    this.original,
  });

  final UserFormModel model;
  final bool isEdit;

  /// Bloqueia a digitação (enquanto envia).
  final bool readOnly;
  final bool showPassword;
  final ValueChanged<bool> onShowPasswordChanged;

  /// Usuário carregado (só na edição): base para "não apagar" opcionais.
  final UserSummary? original;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            isEdit ? 'Dados do usuário' : 'Dados do novo usuário',
            style: theme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: model.nameKey,
          controller: model.name,
          readOnly: readOnly,
          decoration: const InputDecoration(labelText: 'Nome completo'),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => model.clearServerError('name', model.nameKey),
          validator: (v) =>
              UserFormValidators.name(v) ?? model.serverErrors['name'],
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: model.documentKey,
          controller: model.document,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: 'Documento (opcional)',
            helperText: isEdit ? 'Para trocar, digite o novo valor.' : null,
          ),
          textInputAction: TextInputAction.next,
          onChanged: (_) =>
              model.clearServerError('document', model.documentKey),
          validator: (v) =>
              UserFormValidators.document(v) ??
              (isEdit
                  ? UserFormValidators.keepFilled(
                      v,
                      original: original?.document,
                    )
                  : null) ??
              model.serverErrors['document'],
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: model.emailKey,
          controller: model.email,
          readOnly: readOnly,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            helperText: 'É com o e-mail que a pessoa entra no sistema.',
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => model.clearServerError('email', model.emailKey),
          validator: (v) =>
              UserFormValidators.email(v) ?? model.serverErrors['email'],
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: model.phoneKey,
          controller: model.phone,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: 'Telefone (opcional)',
            helperText: isEdit ? 'Para trocar, digite o novo valor.' : null,
          ),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: (_) => model.clearServerError('phone', model.phoneKey),
          validator: (v) =>
              UserFormValidators.phone(v) ??
              (isEdit
                  ? UserFormValidators.keepFilled(
                      v,
                      original: original?.phone,
                    )
                  : null) ??
              model.serverErrors['phone'],
        ),
        const SizedBox(height: 20),
        RoleSelector(
          key: model.roleKey,
          initialValue: model.role,
          enabled: !readOnly,
          onChanged: (role) {
            model.role = role;
            model.clearServerError('role', model.roleKey);
          },
          validator: (role) =>
              UserFormValidators.role(role ?? model.role) ??
              model.serverErrors['role'],
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: model.passwordKey,
          controller: model.password,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: isEdit ? 'Nova senha (opcional)' : 'Senha',
            helperText: isEdit
                ? 'Deixe em branco para manter a senha atual.'
                : 'Mínimo de 6 caracteres.',
          ),
          obscureText: !showPassword,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) =>
              model.clearServerError('password', model.passwordKey),
          validator: (v) =>
              UserFormValidators.password(v, required: !isEdit) ??
              model.serverErrors['password'],
        ),
        CheckboxListTile(
          value: showPassword,
          onChanged: (value) => onShowPasswordChanged(value ?? false),
          title: const Text('Mostrar senha'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
