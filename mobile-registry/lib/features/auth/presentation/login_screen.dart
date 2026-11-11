import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/settings_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/status_message.dart';
import '../application/auth_providers.dart';
import 'login_validators.dart';

/// Login do administrador (US-04).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final login = ref.watch(loginControllerProvider);
    final settings = ref.watch(settingsProvider);
    final endReason = ref.watch(authProvider.select((s) => s.endReason));

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Acesso')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      'Entrar',
                      style: theme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use sua conta de administrador.',
                    style: theme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Explica por que o usuário voltou ao login (US-05).
                  if (endReason == SessionEndReason.expired &&
                      login.error == null) ...[
                    const StatusMessage(
                      kind: StatusKind.info,
                      message: ApiException.unauthorizedMessage,
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextFormField(
                    controller: _email,
                    readOnly: login.loading,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    validator: LoginValidators.email,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _password,
                    readOnly: login.loading,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: !_showPassword,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => _submit(),
                    validator: LoginValidators.password,
                  ),
                  CheckboxListTile(
                    value: _showPassword,
                    onChanged: (value) =>
                        setState(() => _showPassword = value ?? false),
                    title: const Text('Mostrar senha'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  if (login.error != null) ...[
                    StatusMessage(
                      kind: StatusKind.error,
                      message: login.error!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppPrimaryButton(
                    label: 'Entrar',
                    icon: Icons.login,
                    isLoading: login.loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 32),
                  InfoCard(
                    title: 'Servidor configurado',
                    value: settings.baseUrl,
                  ),
                  const SizedBox(height: 16),
                  AppSecondaryButton(
                    label: 'Configurar servidor',
                    icon: Icons.settings,
                    onPressed: login.loading
                        ? null
                        : () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
