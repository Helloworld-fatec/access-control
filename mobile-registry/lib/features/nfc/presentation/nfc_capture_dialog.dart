import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nfc/nfc_service.dart';
import '../../../core/nfc/nfc_uid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_message.dart';

/// Abre a leitura de uma tag NFC (US-11). Devolve o UID padronizado quando o
/// usuário confirma, ou `null` se cancelar.
///
/// Mostra a instrução durante a leitura, o resultado (sucesso ou falha) e
/// mensagens claras se o aparelho não tiver NFC ou ele estiver desligado. Dá
/// também a opção de digitar o código, para aparelhos sem NFC.
Future<String?> showNfcCaptureDialog(
  BuildContext context, {
  String title = 'Ler tag NFC',
  String instruction =
      'Aproxime a tag NFC da parte de trás do celular e espere um instante.',
  String confirmLabel = 'Usar esta tag',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => NfcCaptureDialog(
      title: title,
      instruction: instruction,
      confirmLabel: confirmLabel,
    ),
  );
}

enum _Phase { checking, waiting, read, failed, unavailable, manual }

class NfcCaptureDialog extends ConsumerStatefulWidget {
  const NfcCaptureDialog({
    super.key,
    required this.title,
    required this.instruction,
    required this.confirmLabel,
  });

  final String title;
  final String instruction;
  final String confirmLabel;

  @override
  ConsumerState<NfcCaptureDialog> createState() => _NfcCaptureDialogState();
}

class _NfcCaptureDialogState extends ConsumerState<NfcCaptureDialog> {
  late final NfcService _nfc;
  final _manual = TextEditingController();

  _Phase _phase = _Phase.checking;
  NfcHardwareStatus _status = NfcHardwareStatus.available;
  String? _uid;
  String _failure = '';
  String? _manualError;

  /// Identifica a tentativa vigente: resultados de leituras antigas
  /// (canceladas ou substituídas) são descartados.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _nfc = ref.read(nfcServiceProvider);
    unawaited(_start());
  }

  @override
  void dispose() {
    _manual.dispose();
    unawaited(_nfc.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;

    final status = await _nfc.checkAvailability();
    if (!mounted || attempt != _attempt) return;
    if (status != NfcHardwareStatus.available) {
      setState(() {
        _status = status;
        _phase = _Phase.unavailable;
      });
      return;
    }

    setState(() => _phase = _Phase.waiting);
    try {
      final uid = await _nfc.readUid();
      if (!mounted || attempt != _attempt) return;
      if (!NfcUid.isValid(uid)) {
        setState(() {
          _failure = 'O código desta tag está fora do padrão aceito pelo '
              'sistema. Tente outra tag.';
          _phase = _Phase.failed;
        });
        return;
      }
      setState(() {
        _uid = uid;
        _phase = _Phase.read;
      });
    } on NfcReadException catch (e) {
      if (e.cancelled || !mounted || attempt != _attempt) return;
      setState(() {
        _failure = e.message;
        _phase = _Phase.failed;
      });
    }
  }

  void _retry() {
    unawaited(_nfc.cancel());
    setState(() {
      _uid = null;
      _phase = _Phase.checking;
    });
    unawaited(_start());
  }

  void _goManual() {
    _attempt++; // descarta a leitura em andamento
    unawaited(_nfc.cancel());
    setState(() {
      _manualError = null;
      _phase = _Phase.manual;
    });
  }

  void _useManual() {
    final uid = NfcUid.tryNormalize(_manual.text);
    if (uid == null) {
      setState(() {
        _manualError = 'Código inválido. Use de 8 a 20 caracteres '
            'hexadecimais (0 a 9 e A a F), em número par.';
      });
      return;
    }
    setState(() {
      _uid = uid;
      _phase = _Phase.read;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(widget.title, style: theme.titleLarge),
              ),
              const SizedBox(height: 16),
              ..._content(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(TextTheme theme) {
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    );
    final typeCode = TextButton(
      onPressed: _goManual,
      child: const Text('Digitar o código manualmente'),
    );

    switch (_phase) {
      case _Phase.checking:
        return [
          Semantics(
            liveRegion: true,
            label: 'Verificando o NFC',
            child: const Center(child: CircularProgressIndicator(strokeWidth: 4)),
          ),
          const SizedBox(height: 12),
          Text('Verificando o NFC...', style: theme.bodyLarge, textAlign: TextAlign.center),
        ];

      case _Phase.waiting:
        return [
          const ExcludeSemantics(
            child: Icon(Icons.nfc, size: 72, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.instruction,
              style: theme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 8),
          const SizedBox(height: 16),
          AppSecondaryButton(
            label: 'Cancelar',
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          typeCode,
        ];

      case _Phase.read:
        return [
          const StatusMessage(
            kind: StatusKind.success,
            message: 'Tag lida com sucesso.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Semantics(
                container: true,
                label: 'Código da tag: $_uid',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código da tag', style: theme.bodyMedium),
                      Text(
                        _uid!,
                        style: theme.titleMedium?.copyWith(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: widget.confirmLabel,
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(_uid),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Ler outra tag',
            icon: Icons.nfc,
            onPressed: _retry,
          ),
          cancel,
        ];

      case _Phase.failed:
        return [
          StatusMessage(kind: StatusKind.error, message: _failure),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Tentar de novo',
            icon: Icons.refresh,
            onPressed: _retry,
          ),
          typeCode,
          cancel,
        ];

      case _Phase.unavailable:
        return [
          StatusMessage(
            kind: StatusKind.error,
            message: _status == NfcHardwareStatus.unsupportedPlatform
                ? 'Este aparelho não permite ler tags NFC.'
                : 'O NFC não está disponível. Este aparelho pode não ter NFC '
                    'ou ele está desligado. Ligue o NFC nas configurações do '
                    'aparelho e tente de novo.',
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Tentar de novo',
            icon: Icons.refresh,
            onPressed: _retry,
          ),
          typeCode,
          cancel,
        ];

      case _Phase.manual:
        return [
          TextField(
            controller: _manual,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Código (UID) da tag',
              helperText: 'Exemplo: 04A32F1B ou 04:A3:2F:1B',
              errorText: _manualError,
            ),
            onChanged: (_) {
              if (_manualError != null) setState(() => _manualError = null);
            },
            onSubmitted: (_) => _useManual(),
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Usar este código',
            icon: Icons.check,
            onPressed: _useManual,
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Ler pelo NFC',
            icon: Icons.nfc,
            onPressed: _retry,
          ),
          cancel,
        ];
    }
  }
}
