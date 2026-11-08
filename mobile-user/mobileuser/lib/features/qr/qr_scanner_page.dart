import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_scope.dart';
import '../../core/theme/app_colors.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false, _cameraGranted = false, _openingSettings = false;
  String? _cameraError, _resultTitle, _resultMessage;
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      _cameraGranted = true;
      await _startScanner();
      return;
    }
    final requested = await Permission.camera.request();
    if (!mounted) return;
    if (requested.isGranted) {
      _cameraGranted = true;
      await _startScanner();
    } else {
      setState(
        () => _cameraError = requested.isPermanentlyDenied
            ? 'A permissão da câmera foi negada. Ative-a nas configurações do sistema.'
            : 'É necessária a permissão da câmera para ler o QR Code.',
      );
    }
  }

  Future<void> _startScanner() async {
    if (!_cameraGranted || _processing || !mounted) return;
    try {
      await _controller.start();
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted)
        setState(
          () => _cameraError = 'Não foi possível iniciar a câmera. Verifique se ela está disponível e se o app tem permissão.',
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _prepareCamera();
    } else {
      unawaited(_controller.stop());
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing || _granted != null || _resultTitle != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    dynamic parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      _showMalformed();
      return;
    }
    if (parsed is! Map ||
        parsed['v'] != 1 ||
        parsed['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(parsed['token'] as String)) {
      _showMalformed();
      return;
    }
    unawaited(_consume(parsed['token'] as String));
  }

  void _showMalformed() {
    if (!mounted || _processing) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR inválido. Aponte para um QR de acesso atualizado.'),
      ),
    );
  }

  Future<void> _consume(String value) async {
    if (_processing) return;
    setState(() {
      _processing = true;
    });
    final session = SessionScope.of(context);
    await _controller.stop();
    try {
      final response = await session.consumeQr(value);
      final granted = response['result'] == 'GRANTED';
      if (!granted && response['result'] != 'DENIED')
        throw const QrConsumeException(
          message: 'Resposta inesperada do servidor.',
        );
      if (!mounted) return;
      setState(() {
        _granted = granted;
        _resultTitle = granted ? 'Acesso liberado' : 'Acesso negado';
        _resultMessage = granted
            ? 'A autorização foi confirmada.'
            : _reason(response['reason'] as String?);
      });
    } on QrConsumeException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 && e.code != 'INVALID_CREDENTIAL') {
        setState(() {
          _resultTitle = 'Sessão expirada';
          _resultMessage = 'Entre novamente para continuar.';
        });
      } else {
        setState(() {
          _resultTitle = 'QR não aceito';
          _resultMessage = e.code == 'INVALID_CREDENTIAL'
              ? 'QR inválido ou desconhecido. Leia um QR atualizado.'
              : (e.reason != null ? _reason(e.reason) : e.message);
          _granted = false;
        });
      }
    } on TimeoutException {
      _showNetworkFailure();
    } catch (_) {
      _showNetworkFailure();
    } finally {
      // O token não é guardado em estado, storage, logs ou no resultado da tela.
      value = '';
      if (mounted) setState(() => _processing = false);
    }
  }

  String _reason(String? reason) => switch (reason) {
    'NO_AUTHORIZATION' => 'Você não tem autorização para este local.',
    'AUTHORIZATION_CANCELED' => 'A autorização foi cancelada.',
    'OUTSIDE_PERIOD' => 'A autorização não está válida nesta data.',
    'OUTSIDE_SCHEDULE' => 'A autorização não está válida neste horário.',
    'USES_EXHAUSTED' => 'A autorização já usou todas as entradas disponíveis.',
    'EXPIRED_CREDENTIAL' =>
      'Este QR expirou. Leia o QR atualizado no terminal.',
    'REPLAYED_CREDENTIAL' =>
      'Este QR já foi utilizado. Leia o QR atualizado no terminal.',
    'USER_INACTIVE' => 'O usuário está inativo. Procure a administração.',
    'TERMINAL_OFFLINE' => 'O terminal está offline.',
    _ => 'O acesso foi negado. Verifique sua autorização.',
  };

  void _showNetworkFailure() {
    if (mounted)
      setState(() {
        _resultTitle = 'Não foi possível confirmar';
        _resultMessage = 'Falha de rede. Não é possível afirmar que a porta abriu. Conecte-se à rede e leia um QR atualizado.';
        _granted = false;
      });
  }

  Future<void> _retry() async {
    setState(() {
      _resultTitle = null;
      _resultMessage = null;
      _granted = null;
      _cameraError = null;
    });
    await _startScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _resultTitle != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(result ? _resultTitle! : 'Ler QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: result ? _resultView() : _scannerView()),
    );
  }

  Widget _scannerView() {
    if (_cameraError != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 64),
              const SizedBox(height: 16),
              Text(_cameraError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (_cameraError!.contains('configurações'))
                FilledButton.icon(
                  onPressed: () async {
                    setState(() => _openingSettings = true);
                    await openAppSettings();
                    if (mounted) setState(() => _openingSettings = false);
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir configurações'),
                )
              else
                FilledButton(
                  onPressed: _prepareCamera,
                  child: const Text('Tentar novamente'),
                ),
              if (_openingSettings)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      );
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Permissão da câmera negada. Verifique as configurações.'
                  : 'Câmera indisponível: ${error.errorCode.name}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.yellow, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _processing
                  ? 'Validando acesso…'
                  : 'Aponte a câmera para o QR Code exibido no terminal.',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (_processing)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _resultView() {
    final granted = _granted == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.error_outline,
              size: 88,
              color: granted ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              _resultTitle!,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(_resultMessage ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 28),
            if (_resultTitle == 'Sessão expirada')
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar ao login'),
              )
            else if (granted)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar ao início'),
              )
            else
              Column(
                children: [
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Ler outro QR Code'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
