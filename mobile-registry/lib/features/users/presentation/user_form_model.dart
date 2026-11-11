import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/user_models.dart';

/// Estado do formulário de dados do usuário, compartilhado pelo assistente
/// de cadastro e pela edição: campos, erros apontados pelo backend e conversão
/// para o que a API espera. Quem o cria deve chamar [dispose].
class UserFormModel {
  final formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final document = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();

  // Uma chave por campo: permite revalidar só o campo que o usuário editou.
  final nameKey = GlobalKey<FormFieldState<String>>();
  final documentKey = GlobalKey<FormFieldState<String>>();
  final emailKey = GlobalKey<FormFieldState<String>>();
  final phoneKey = GlobalKey<FormFieldState<String>>();
  final passwordKey = GlobalKey<FormFieldState<String>>();
  final roleKey = GlobalKey<FormFieldState<UserRole>>();

  UserRole? role;

  /// Erros que o backend apontou por campo (`details: [{path, message}]`).
  Map<String, String> serverErrors = {};

  /// Preenche os campos com um usuário existente (edição).
  void fill(UserSummary user) {
    name.text = user.name;
    email.text = user.email;
    document.text = user.document ?? '';
    phone.text = user.phone ?? '';
    role = user.role;
  }

  /// O usuário editou um campo que o backend tinha recusado: tira o erro do
  /// servidor e revalida só esse campo (o erro some da tela na hora).
  void clearServerError(String field, GlobalKey<FormFieldState<dynamic>> key) {
    if (serverErrors.remove(field) != null) {
      key.currentState?.validate();
    }
  }

  /// Registra o erro da API nos campos. Devolve a mensagem do aviso e se o
  /// erro diz respeito aos campos de dados (a tela deve levar o usuário a eles).
  ({String message, bool fieldsAffected}) applyApiError(ApiException api) {
    final fieldErrors = api.fieldErrors;
    if (api.kind == ApiErrorKind.validation && fieldErrors.isNotEmpty) {
      serverErrors = Map.of(fieldErrors);
      return (
        message: 'Confira os campos destacados e tente de novo.',
        fieldsAffected: true,
      );
    }
    if (api.kind == ApiErrorKind.conflict) {
      // O backend não diz qual campo repetiu. Sem documento informado, só
      // pode ser o e-mail; com documento, fica só a mensagem geral.
      if (document.text.trim().isEmpty) {
        serverErrors = {'email': api.message};
      }
      return (message: api.message, fieldsAffected: true);
    }
    return (message: api.message, fieldsAffected: false);
  }

  /// Algo foi digitado? (para saber se vale perguntar antes de descartar)
  bool get hasData =>
      name.text.trim().isNotEmpty ||
      document.text.trim().isNotEmpty ||
      email.text.trim().isNotEmpty ||
      phone.text.trim().isNotEmpty ||
      password.text.isNotEmpty ||
      role != null;

  /// Dados do formulário no formato de cadastro (`POST /users`).
  NewUser toNewUser() => NewUser(
        name: name.text,
        email: email.text,
        password: password.text,
        role: role!,
        document: document.text,
        phone: phone.text,
      );

  /// Campos que mudaram em relação ao usuário carregado (edição).
  Map<String, Object?> changesFrom(UserSummary original) {
    final changes = <String, Object?>{};

    final newName = name.text.trim();
    if (newName != original.name) changes['name'] = newName;

    final newEmail = email.text.trim().toLowerCase();
    if (newEmail != original.email.toLowerCase()) changes['email'] = newEmail;

    // Em branco = "manter": o backend ignora opcional vazio no PUT.
    final newDocument = document.text.trim();
    if (newDocument.isNotEmpty && newDocument != (original.document ?? '')) {
      changes['document'] = newDocument;
    }
    final newPhone = phone.text.trim();
    if (newPhone.isNotEmpty && newPhone != (original.phone ?? '')) {
      changes['phone'] = newPhone;
    }

    if (role != null && role != original.role) changes['role'] = role!.value;
    if (password.text.isNotEmpty) changes['password'] = password.text;
    return changes;
  }

  void dispose() {
    name.dispose();
    document.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }
}
