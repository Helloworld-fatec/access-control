import 'dart:convert';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/face_capture.dart';
import '../services/face_capture_file_web.dart'
    if (dart.library.io) '../services/face_capture_file_io.dart';
import '../state/terminal_controller.dart';
import 'settings_screen.dart';

bool _isBackgrounded(AppLifecycleState state) =>
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.detached;

class TerminalScreen extends StatefulWidget {
  final TerminalController controller;

  const TerminalScreen({super.key, required this.controller});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  TerminalController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isBackgrounded(state) && _controller.state != TerminalState.idle) {
      _controller.returnToIdle();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: _controller),
      ),
    );
  }

  VoidCallback? _backAction(TerminalState state) => switch (state) {
        TerminalState.idle => null,
        TerminalState.choosing => _controller.returnToIdle,
        _ => _controller.showChoices,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final back = _backAction(state);
        final title = switch (state) {
          TerminalState.idle => 'Terminal de Acesso',
          TerminalState.choosing => 'Escolha como acessar',
          TerminalState.qr => 'QR Code',
          _ => 'Reconhecimento facial',
        };
        return PopScope(
          canPop: back == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back?.call();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: back == null ? null : BackButton(onPressed: back),
              actions: [
                if (state == TerminalState.idle && _controller.initialized)
                  IconButton(
                    key: const Key('btn_open_settings'),
                    tooltip: 'Configuração',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(24),
                    children: _content(context, state),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, TerminalState state) {
    if (!_controller.initialized) {
      return const [Center(child: CircularProgressIndicator())];
    }
    switch (state) {
      case TerminalState.idle:
        final configured = _controller.config.isConfigured;
        return [
          Icon(
            Icons.badge_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('btn_wake_terminal'),
            onPressed: configured ? _controller.activate : _openSettings,
            child: Text(configured ? 'Iniciar acesso' : 'Configurar terminal'),
          ),
        ];
      case TerminalState.choosing:
        return [
          FilledButton.icon(
            onPressed: _controller.showQr,
            icon: const Icon(Icons.qr_code),
            label: const Text('QR Code'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _controller.showFacial,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('Reconhecimento facial'),
          ),
        ];
      case TerminalState.qr:
        final token = _controller.currentQrToken;
        final error = _controller.qrError;
        if (token == null && error == null) {
          return const [Center(child: CircularProgressIndicator())];
        }
        return [
          if (token != null) ...[
            const Text(
              'Escaneie com o app de acesso.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: QrImageView(
                  data: jsonEncode(token.payload),
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR Code de acesso',
                ),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(error, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('btn_retry_qr'),
              onPressed:
                  _controller.canRetryQr ? _controller.refreshQrCodeNow : null,
              child: const Text('Tentar novamente'),
            ),
          ],
        ];
      case TerminalState.facial:
        return [
          _FacialCamera(
            capturing: _controller.isCapturing,
            onCapture: _controller.startRecognition,
            onUnavailable: _controller.cameraUnavailable,
          ),
        ];
      case TerminalState.validatingFacial:
        return const [
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 16),
          Text('Validando acesso...', textAlign: TextAlign.center),
        ];
      case TerminalState.facialResult:
        final result = _controller.facialResult!;
        return [
          Icon(
            result.isGranted ? Icons.check_circle_outline : Icons.info_outline,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(result.message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          if (!result.isGranted) ...[
            FilledButton(
              onPressed: _controller.showFacial,
              child: const Text('Tentar novamente'),
            ),
            OutlinedButton(
              onPressed: _controller.showQr,
              child: const Text('Usar QR Code'),
            ),
          ] else
            FilledButton(
              onPressed: _controller.returnToIdle,
              child: const Text('Concluir'),
            ),
        ];
    }
  }
}

class _FacialCamera extends StatefulWidget {
  final bool capturing;
  final Future<void> Function(Future<List<List<int>>> Function()) onCapture;
  final VoidCallback onUnavailable;

  const _FacialCamera({
    required this.capturing,
    required this.onCapture,
    required this.onUnavailable,
  });

  @override
  State<_FacialCamera> createState() => _FacialCameraState();
}

class _FacialCameraState extends State<_FacialCamera>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _closed = false;

  bool get _active => mounted && !_closed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openFrontCamera());
  }

  Future<void> _openFrontCamera() async {
    CameraController? pending;
    try {
      final cameras = await availableCameras();
      if (!_active) return;
      final front = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.front)
          .firstOrNull;
      if (front == null) {
        widget.onUnavailable();
        return;
      }
      final camera = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
      );
      pending = camera;
      await camera.initialize();
      if (!_active) return;
      setState(() => _camera = camera);
      pending = null;
    } on Exception {
      if (_active) widget.onUnavailable();
    } finally {
      await pending?.dispose();
    }
  }

  Future<List<List<int>>> _capture() async {
    final camera = _camera!;
    final photos = <List<int>>[];
    for (var index = 0; index < maxFaceCaptures; index++) {
      if (!_active) break;
      final file = await camera.takePicture();
      try {
        if (!_active) break;
        if (await file.length() <= maxFacePhotoBytes && _active) {
          final bytes = await file.readAsBytes();
          if (!_active) break;
          if (isSupportedFaceJpeg(bytes)) photos.add(bytes);
        }
      } finally {
        await discardFaceCaptureFile(file.path);
      }
      if (_active && index + 1 < maxFaceCaptures) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return photos;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isBackgrounded(state)) _closeCamera();
  }

  void _closeCamera() {
    _closed = true;
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(camera.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    if (camera == null) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CameraPreview(camera),
        ),
        const SizedBox(height: 16),
        const Text(
          'Posicione o rosto no centro da imagem.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.capturing ? null : () => widget.onCapture(_capture),
          child: Text(
            widget.capturing ? 'Capturando...' : 'Iniciar reconhecimento',
          ),
        ),
      ],
    );
  }
}
