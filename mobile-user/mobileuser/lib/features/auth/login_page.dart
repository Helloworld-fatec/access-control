import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/warning_stripe.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final url = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool loading = false;
  String? error;
  @override
  void dispose() {
    url.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (loading) return;
    if (url.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      setState(() {
        error = 'Preencha URL, e-mail e senha.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await SessionScope.of(context).login(url.text, email.text, password.text);
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          error = e.message;
        });
    } on TimeoutException {
      if (mounted)
        setState(() {
          error = 'O servidor demorou para responder.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'Sem conexao. Confira a URL e se ambos estao no mesmo Wi-Fi.';
        });
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const WarningStripe(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  Text(
                    'Controle de Acesso',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use o endereco do backend na rede local.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'URL do backend',
                      hintText: 'http://192.168.0.10:3000',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => login(),
                    decoration: const InputDecoration(labelText: 'Senha'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('ENTRAR'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
