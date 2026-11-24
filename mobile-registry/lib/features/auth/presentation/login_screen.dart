import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_message.dart';
import '../application/session_controller.dart';
import 'login_validators.dart';

/// Login do administrador (US-04).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressKey = GlobalKey<FormFieldState<String>>();
  late final _address = TextEditingController(
    text: widget.session.server.origin,
  );
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _checked = false;
  String? _connectionError;

  @override
  void dispose() {
    _address.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.session.busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.session.submit(
      email: _email.text,
      password: _password.text,
      server: _serverAddress(),
    );
  }

  Uri _serverAddress() => LoginValidators.parseServerAddress(_address.text)!;

  Future<void> _checkConnection() async {
    if (widget.session.busy) return;
    if (!_addressKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _checked = false);
    final error = await widget.session.checkConnection(_serverAddress());
    if (!mounted) return;
    setState(() {
      _checked = true;
      _connectionError = error;
    });
  }

  void _addressChanged(String _) {
    if (_checked) setState(() => _checked = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final login = widget.session;
    final endReason = login.endReason;

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
                  const Center(child: AppLogo()),
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
                    key: _addressKey,
                    controller: _address,
                    readOnly: login.busy,
                    decoration: const InputDecoration(
                      labelText: 'Endereço do servidor',
                      hintText: '192.168.1.25:3333 ou https://…',
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    validator: LoginValidators.serverAddress,
                    onChanged: _addressChanged,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    label: 'Testar conexão',
                    onPressed: login.busy ? null : _checkConnection,
                    isLoading: login.checking,
                  ),
                  if (_checked) ...[
                    const SizedBox(height: 12),
                    StatusMessage(
                      kind: _connectionError == null
                          ? StatusKind.success
                          : StatusKind.error,
                      message:
                          _connectionError ??
                          'Conexão com o servidor confirmada.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    readOnly: login.busy,
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
                    readOnly: login.busy,
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
                    onPressed: login.busy ? null : _submit,
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
