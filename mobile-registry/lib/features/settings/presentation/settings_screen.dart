import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/config/settings_providers.dart';
import '../../../core/config/settings_validators.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_message.dart';
import '../application/connection_test_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _Feedback {
  const _Feedback(this.kind, this.message);
  final StatusKind kind;
  final String message;
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _photoKb;
  late int _samples;
  bool _saving = false;
  _Feedback? _feedback;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _host = TextEditingController(text: s.host);
    _port = TextEditingController(text: '${s.port}');
    _photoKb = TextEditingController(text: '${s.maxPhotoKb}');
    _samples = s.faceSamples;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _photoKb.dispose();
    super.dispose();
  }

  AppSettings? _readForm() {
    if (!_formKey.currentState!.validate()) return null;
    return AppSettings(
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      maxPhotoKb: int.parse(_photoKb.text.trim()),
      faceSamples: _samples,
    );
  }

  Future<bool> _persist() async {
    final settings = _readForm();
    if (settings == null) {
      setState(() {
        _feedback = const _Feedback(
          StatusKind.error,
          'Confira os campos destacados e tente de novo.',
        );
      });
      return false;
    }

    setState(() {
      _saving = true;
      _feedback = null;
    });
    try {
      await ref.read(settingsProvider.notifier).save(settings);
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _feedback = const _Feedback(
          StatusKind.error,
          'Não foi possível salvar as configurações. Tente novamente.',
        );
      });
      return false;
    }
    if (!mounted) return false;
    setState(() => _saving = false);
    return true;
  }

  Future<void> _onSave() async {
    ref.read(connectionTestProvider.notifier).reset();
    if (await _persist() && mounted) {
      setState(() {
        _feedback = const _Feedback(
          StatusKind.success,
          'Configurações salvas. Elas já valem para as próximas ações.',
        );
      });
    }
  }

  Future<void> _onSaveAndTest() async {
    ref.read(connectionTestProvider.notifier).reset();
    if (await _persist()) {
      await ref.read(connectionTestProvider.notifier).run();
    }
  }

  void _restoreDefaults() {
    setState(() {
      _host.text = AppSettings.defaultHost;
      _port.text = '${AppSettings.defaultPort}';
      _photoKb.text = '${AppSettings.defaultMaxPhotoKb}';
      _samples = AppSettings.defaultFaceSamples;
      _feedback = const _Feedback(
        StatusKind.success,
        'Valores padrão colocados nos campos. Toque em Salvar para aplicar.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final test = ref.watch(connectionTestProvider);
    final testing = test.status == ConnectionStatus.loading;
    final busy = _saving || testing;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text('Servidor', style: theme.titleLarge),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _host,
                  decoration: const InputDecoration(
                    labelText: 'Endereço do servidor (IP)',
                    helperText:
                        'Exemplo: 192.168.0.10. No emulador Android use 10.0.2.2.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  validator: SettingsValidators.host,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _port,
                  decoration: const InputDecoration(
                    labelText: 'Porta do servidor',
                    helperText: 'Normalmente 3000.',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: SettingsValidators.port,
                ),
                const SizedBox(height: 32),
                Semantics(
                  header: true,
                  child: Text('Fotos e rosto', style: theme.titleLarge),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _photoKb,
                  decoration: const InputDecoration(
                    labelText: 'Tamanho máximo da foto (KB)',
                    helperText: 'Padrão: 50. Fotos menores enviam mais rápido.',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: SettingsValidators.photoKb,
                ),
                const SizedBox(height: 20),
                Text(
                  'Capturas do rosto por cadastro',
                  style: theme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Semantics(
                  container: true,
                  label: 'Capturas do rosto por cadastro. '
                      'Selecionado: $_samples',
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 4, label: Text('4')),
                      ButtonSegment(value: 5, label: Text('5')),
                    ],
                    selected: {_samples},
                    onSelectionChanged: (selection) =>
                        setState(() => _samples = selection.first),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mais capturas deixam o reconhecimento mais confiável, '
                  'mas o cadastro demora um pouco mais.',
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                if (_feedback != null) ...[
                  StatusMessage(
                    kind: _feedback!.kind,
                    message: _feedback!.message,
                  ),
                  const SizedBox(height: 16),
                ],
                if (test.status == ConnectionStatus.success ||
                    test.status == ConnectionStatus.failure) ...[
                  StatusMessage(
                    kind: test.status == ConnectionStatus.success
                        ? StatusKind.success
                        : StatusKind.error,
                    message: test.message,
                  ),
                  const SizedBox(height: 16),
                ],
                AppPrimaryButton(
                  label: 'Salvar',
                  icon: Icons.save,
                  isLoading: _saving,
                  onPressed: busy ? null : _onSave,
                ),
                const SizedBox(height: 16),
                AppSecondaryButton(
                  label: 'Salvar e testar conexão',
                  icon: Icons.wifi_find,
                  isLoading: testing,
                  onPressed: busy ? null : _onSaveAndTest,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _restoreDefaults,
                  child: const Text('Restaurar valores padrão'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
