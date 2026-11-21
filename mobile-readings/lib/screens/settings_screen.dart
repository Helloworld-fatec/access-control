import 'package:flutter/material.dart';

import '../config/terminal_config.dart';
import '../services/api_client.dart';
import '../state/terminal_controller.dart';

class SettingsScreen extends StatefulWidget {
  final TerminalController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _key;
  bool _obscureKey = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.config;
    _address = TextEditingController(text: config.serverAddress ?? '');
    _key = TextEditingController(text: config.apiKey);
  }

  @override
  void dispose() {
    _address.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final address = _address.text;
    final key = _key.text;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.controller.configureTerminal(address, key);
    } on TerminalApiException catch (error) {
      _showError(error.message);
      return;
    } on Exception {
      _showError('Não foi possível salvar a configuração com segurança.');
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terminal autenticado e configuração salva.'),
      ),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Configuração do Terminal')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const Key('field_server_address'),
                controller: _address,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Endereço do servidor',
                  hintText: 'https://servidor.exemplo ou 192.168.1.100:3000',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    TerminalConfig.normalizeServerAddress(value ?? '') == null
                        ? 'Informe uma URL HTTP/HTTPS ou IP:porta válido.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field_terminal_key'),
                controller: _key,
                enabled: !_saving,
                obscureText: _obscureKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Chave do terminal',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscureKey ? 'Mostrar chave' : 'Ocultar chave',
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: TerminalConfig.validateTerminalKey,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('btn_save_settings'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Verificando...' : 'Validar e salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
