import 'package:flutter/material.dart';

import '../config/terminal_config.dart';
import '../state/terminal_controller.dart';

/// Tela funcional de configuração do Terminal de Acesso (US-02, US-03).
class SettingsScreen extends StatefulWidget {
  final TerminalController controller;

  const SettingsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _backendHostCtrl;
  late final TextEditingController _backendPortCtrl;
  late final TextEditingController _mqttHostCtrl;
  late final TextEditingController _mqttPortCtrl;
  late final TextEditingController _mqttUserCtrl;
  late final TextEditingController _mqttPasswordCtrl;
  late final TextEditingController _terminalIdCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _inactivityCtrl;
  late final TextEditingController _faceThresholdCtrl;

  late bool _useHttps;
  late bool _simulationMode;
  late bool _voiceAccessibility;
  late bool _kioskMode;
  late bool _preferFaceAuth;
  bool _obscureApiKey = true;
  bool _obscureMqttPassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.controller.config;
    _backendHostCtrl = TextEditingController(text: cfg.backendHost);
    _backendPortCtrl = TextEditingController(text: cfg.backendPort.toString());
    _mqttHostCtrl = TextEditingController(text: cfg.mqttHost);
    _mqttPortCtrl = TextEditingController(text: cfg.mqttPort.toString());
    _mqttUserCtrl = TextEditingController(text: cfg.mqttUsername);
    _mqttPasswordCtrl = TextEditingController(text: cfg.mqttPassword);
    _terminalIdCtrl = TextEditingController(text: cfg.terminalId);
    _apiKeyCtrl = TextEditingController(text: cfg.apiKey);
    _inactivityCtrl =
        TextEditingController(text: cfg.inactivityTimeoutSeconds.toString());
    _faceThresholdCtrl = TextEditingController(
      text: cfg.faceSimilarityThreshold.toStringAsFixed(2),
    );
    _useHttps = cfg.useHttps;
    _simulationMode = cfg.simulationMode;
    _voiceAccessibility = cfg.voiceAccessibilityEnabled;
    _kioskMode = cfg.kioskModeEnabled;
    _preferFaceAuth = cfg.preferFaceAuth;
  }

  @override
  void dispose() {
    _backendHostCtrl.dispose();
    _backendPortCtrl.dispose();
    _mqttHostCtrl.dispose();
    _mqttPortCtrl.dispose();
    _mqttUserCtrl.dispose();
    _mqttPasswordCtrl.dispose();
    _terminalIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    _inactivityCtrl.dispose();
    _faceThresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final updated = TerminalConfig(
      backendHost: _backendHostCtrl.text.trim(),
      backendPort: int.parse(_backendPortCtrl.text.trim()),
      useHttps: _useHttps,
      mqttHost: _mqttHostCtrl.text.trim(),
      mqttPort: int.parse(_mqttPortCtrl.text.trim()),
      mqttUsername: _mqttUserCtrl.text.trim(),
      mqttPassword: _mqttPasswordCtrl.text,
      terminalId: _terminalIdCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      inactivityTimeoutSeconds: int.parse(_inactivityCtrl.text.trim()),
      faceSimilarityThreshold: double.parse(
        _faceThresholdCtrl.text.trim().replaceAll(',', '.'),
      ),
      simulationMode: _simulationMode,
      voiceAccessibilityEnabled: _voiceAccessibility,
      kioskModeEnabled: _kioskMode,
      preferFaceAuth: _preferFaceAuth,
    );

    await widget.controller.updateConfig(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas e aplicadas.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração do Terminal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo de Simulação (Mock Local)'),
              subtitle: const Text(
                'Permite testar QR Code e leitura NFC sem precisar do backend ou broker MQTT ativos.',
              ),
              value: _simulationMode,
              onChanged: (v) => setState(() => _simulationMode = v),
            ),
            const Divider(),
            const Text(
              'Servidor Backend (API REST)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const Key('field_backend_host'),
                    controller: _backendHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Endereço do Backend (IP/Host)',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validateHost,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('field_backend_port'),
                    controller: _backendPortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Porta HTTP',
                      hintText: '3000',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validatePort,
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar HTTPS'),
              value: _useHttps,
              onChanged: (v) => setState(() => _useHttps = v),
            ),
            const Divider(),
            const Text(
              'Identificação do Terminal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('field_terminal_id'),
              controller: _terminalIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Identificador do Terminal (ID)',
                border: OutlineInputBorder(),
              ),
              validator: TerminalConfig.validateTerminalId,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('field_api_key'),
              controller: _apiKeyCtrl,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Chave da API do Terminal (apiKey)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Broker MQTT (Mosquitto)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const Key('field_mqtt_host'),
                    controller: _mqttHostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Endereço do Broker MQTT',
                      hintText: '192.168.1.100',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validateHost,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('field_mqtt_port'),
                    controller: _mqttPortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Porta MQTT',
                      hintText: '1883',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validatePort,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('field_mqtt_user'),
                    controller: _mqttUserCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Usuário MQTT (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('field_mqtt_password'),
                    controller: _mqttPasswordCtrl,
                    obscureText: _obscureMqttPassword,
                    decoration: InputDecoration(
                      labelText: 'Senha MQTT (opcional)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureMqttPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureMqttPassword = !_obscureMqttPassword,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Parâmetros de Operação e Biometria (US-19)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('field_inactivity_seconds'),
                    controller: _inactivityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Inatividade até Repouso (s)',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validateInactivitySeconds,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('field_face_threshold'),
                    controller: _faceThresholdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Limiar Facial (0.10 - 1.00)',
                      border: OutlineInputBorder(),
                    ),
                    validator: TerminalConfig.validateFaceThreshold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('0.65 (Tolerante)'),
                  onPressed: () =>
                      setState(() => _faceThresholdCtrl.text = '0.65'),
                ),
                ActionChip(
                  label: const Text('0.75 (Recomendado)'),
                  onPressed: () =>
                      setState(() => _faceThresholdCtrl.text = '0.75'),
                ),
                ActionChip(
                  label: const Text('0.85 (Alta Precisão)'),
                  onPressed: () =>
                      setState(() => _faceThresholdCtrl.text = '0.85'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Acessibilidade e Operação Dedicada',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sinalização por Voz e Resposta Tátil (US-20)'),
              subtitle: const Text(
                'Emite anúncios falados e vibrações para pessoas com deficiência visual.',
              ),
              value: _voiceAccessibility,
              onChanged: (v) => setState(() => _voiceAccessibility = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo Terminal Dedicado (Kiosk / Wakelock) (US-14)'),
              subtitle: const Text(
                'Mantém o display sempre ativo e a orientação vertical fixa.',
              ),
              value: _kioskMode,
              onChanged: (v) => setState(() => _kioskMode = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Priorizar Câmera Facial ao Acordar (US-16)'),
              subtitle: const Text(
                'Abre diretamente o leitor facial ao detectar presença.',
              ),
              value: _preferFaceAuth,
              onChanged: (v) => setState(() => _preferFaceAuth = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                key: const Key('btn_save_settings'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(
                  _saving ? 'Salvando...' : 'Salvar configurações',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
