import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state/terminal_controller.dart';
import 'settings_screen.dart';

/// Tela principal do Terminal de Acesso (US-04, US-07, US-08, US-09, US-11, US-12, US-13, US-20).
/// Reflete diretamente o estado atual do [TerminalController].
class TerminalScreen extends StatelessWidget {
  final TerminalController controller;
  static final GlobalKey<FaceCameraViewfinderState> _viewfinderKey =
      GlobalKey<FaceCameraViewfinderState>();

  const TerminalScreen({
    super.key,
    required this.controller,
  });

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        switch (controller.state) {
          case TerminalState.idle:
            return _buildIdleView(context);
          case TerminalState.listening:
            return _buildListeningView(context);
          case TerminalState.validating:
            return _buildValidatingView(context);
          case TerminalState.granted:
            return _buildGrantedView(context);
          case TerminalState.denied:
            return _buildDeniedView(context);
        }
      },
    );
  }

  /// Barra de status com identificadores ao vivo de conexão da API Backend e Hardware Arduino.
  PreferredSizeWidget _buildStatusBar(
    BuildContext context, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final mqttOnline = controller.isMqttConnected;
    final apiOnline = !controller.isQrUnavailable;

    Color arduinoDotColor;
    String arduinoLabel;
    if (mqttOnline) {
      if (controller.isReaderBusy) {
        arduinoDotColor = const Color(0xFFF59E0B);
        arduinoLabel = 'Arduino: Gravando';
      } else {
        arduinoDotColor = const Color(0xFF2ECC71);
        arduinoLabel = 'Arduino: Online';
      }
    } else if (controller.isFallbackPollingActive) {
      arduinoDotColor = const Color(0xFFF59E0B);
      arduinoLabel = 'Arduino: Polling';
    } else {
      arduinoDotColor = const Color(0xFF7A8798);
      arduinoLabel = 'Arduino: Offline';
    }

    final apiDotColor = apiOnline ? const Color(0xFF2ECC71) : const Color(0xFFC4152F);
    final apiLabel = apiOnline ? 'API: Online' : 'API: Offline';

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      centerTitle: false,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Identificador do Terminal
            Text(
              controller.config.terminalId,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: foregroundColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),

            // Badge de Status do Backend / API
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: apiDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    apiLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Badge de Status do Arduino / Hardware
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: arduinoDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    arduinoLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: foregroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          key: const Key('btn_open_settings'),
          tooltip: 'Configurações do terminal',
          icon: const Icon(Icons.settings),
          onPressed: () => _openSettings(context),
        ),
      ],
    );
  }

  /// Estado 1: Repouso — tela escura econômica, NFC e câmera desligados (US-13).
  Widget _buildIdleView(BuildContext context) {
    return Scaffold(
      key: const Key('view_state_idle'),
      backgroundColor: const Color(0xFF14171D),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFF14171D),
        foregroundColor: Colors.white70,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sensors,
                size: 72,
                color: Color(0xFFD81E3F),
              ),
              const SizedBox(height: 24),
              const Text(
                'Terminal em repouso',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Aproxime-se da entrada para ativar a leitura.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const Key('btn_wake_terminal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD81E3F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: controller.onPresenceDetected,
                  icon: const Icon(Icons.touch_app),
                  label: const Text(
                    'Ativar terminal manualmente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado 2: Escuta — exibe o QR Code rotativo ou reconhecimento facial (US-07, US-08, US-16, US-17, US-19, US-20).
  Widget _buildListeningView(BuildContext context) {
    final qrToken = controller.currentQrToken;
    final qrUnavailable = controller.isQrUnavailable;
    final isFaceMode = controller.isFaceModeEnabled;

    return Scaffold(
      key: const Key('view_state_listening'),
      backgroundColor: const Color(0xFFECF0F5),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFFD81E3F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Alerta de leitor ocupado para gravação remota de tag (US-10)
                  if (controller.isReaderBusy) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFEEBA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top, color: Color(0xFF856404)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Leitor ocupado gravando tag NFC. Aguarde um instante...',
                              style: TextStyle(
                                color: Color(0xFF856404),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Alternador entre métodos de entrada: QR Code vs Reconhecimento Facial (US-16)
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color(0xFF14171D),
                      selectedForegroundColor: Colors.white,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF14171D),
                      side: const BorderSide(color: Color(0xFFD3DAE4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.qr_code_2),
                        label: Text('QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.face),
                        label: Text('Biometria Facial', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    selected: {isFaceMode},
                    onSelectionChanged: (selected) {
                      controller.setFaceMode(selected.first);
                    },
                  ),
                  const SizedBox(height: 18),

                  if (isFaceMode)
                    _buildFaceCameraView(context)
                  else
                    _buildQrView(context, qrToken, qrUnavailable),

                  if (controller.statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE1E5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFC4152F)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.statusMessage!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFC4152F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Painel de Câmera Frontal e Reconhecimento Facial (US-16, US-17, US-18, US-19).
  Widget _buildFaceCameraView(BuildContext context) {
    final ramCount = controller.faceEmbeddingsCount;
    final thresholdPct =
        (controller.config.faceSimilarityThreshold * 100).toStringAsFixed(0);

    return Column(
      key: const Key('face_camera_view'),
      children: [
        const Text(
          'Reconhecimento Facial',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF14171D),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Olhe diretamente para a câmera para validar seu acesso.',
          style: TextStyle(fontSize: 16, color: Color(0xFF4A5565)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Moldura Viewfinder com Varredura Laser Animada (US-16, US-17, US-19)
        FaceCameraViewfinder(
          key: _viewfinderKey,
          ramCount: ramCount,
          thresholdPct: thresholdPct,
          isSyncing: controller.isFaceSyncLoading,
          onPhotoCaptured: controller.validateCapturedPhoto,
          onFallbackTriggered: controller.simulateFaceAccess,
        ),

        const SizedBox(height: 18),

        // Botão de Ação: Validação Biométrica Oficial (US-16, US-17, US-18)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('btn_sim_face_valid'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF14171D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                elevation: 2,
              ),
              onPressed: () {
                _viewfinderKey.currentState?.captureAndValidate();
              },
              icon: const Icon(Icons.face_unlock_rounded, color: Color(0xFF2ECC71)),
              label: const Text(
                'Validar Biometria Facial',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Sincronizar biometrias',
              icon: const Icon(Icons.sync),
              onPressed: controller.syncFaceEmbeddings,
            ),
          ],
        ),
      ],
    );
  }

  /// Painel de QR Code Dinâmico (US-07, US-08).
  Widget _buildQrView(
    BuildContext context,
    dynamic qrToken,
    bool qrUnavailable,
  ) {
    return Column(
      key: const Key('qr_nfc_view'),
      children: [
        const Text(
          'Identifique-se para entrar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF14171D),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Aponte a câmera do seu celular para o QR Code.',
          style: TextStyle(fontSize: 16, color: Color(0xFF4A5565)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Card do QR Code rotativo ou aviso de indisponibilidade (US-07, US-08)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD3DAE4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: qrUnavailable || qrToken == null
              ? Column(
                  key: const Key('qr_unavailable_box'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      size: 72,
                      color: Color(0xFFC4152F),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'QR indisponível',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC4152F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sem comunicação com o servidor para atualizar o código.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4A5565),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('btn_retry_qr'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD81E3F),
                        side: const BorderSide(color: Color(0xFFD81E3F)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: controller.refreshQrCodeNow,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                )
              : Column(
                  key: const Key('qr_code_box'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: qrToken.token,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Código renovado automaticamente a cada 10s',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5565),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Estado 3: Validando — aguarda resposta do backend (US-10).
  Widget _buildValidatingView(BuildContext context) {
    return Scaffold(
      key: const Key('view_state_validating'),
      backgroundColor: const Color(0xFFECF0F5),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFFD81E3F),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: Color(0xFFD81E3F),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Validando credencial...',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14171D),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Aguarde um instante.',
                style: TextStyle(fontSize: 18, color: Color(0xFF4A5565)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado 4: Liberado — tela verde, ícone de confirmação e texto "Acesso liberado" (US-11).
  Widget _buildGrantedView(BuildContext context) {
    final result = controller.lastAccessResult;
    return Scaffold(
      key: const Key('view_state_granted'),
      backgroundColor: const Color(0xFF14683F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 112,
                  color: Color(0xFF2ECC71),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Acesso liberado',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (result?.userName != null &&
                    result!.userName!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    result.userName!,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Pode passar.',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Feedback de Abertura de Trava / Relé (US-22)
                Container(
                  key: const Key('relay_lock_feedback_box'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open, color: Color(0xFF2ECC71), size: 28),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trava Solenoide / Relé',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Circuito liberado por 3 segundos',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Estado 5: Negado — tela vermelha, ícone e texto com motivo simples ou indisponibilidade (US-11, US-12).
  Widget _buildDeniedView(BuildContext context) {
    final result = controller.lastAccessResult;
    final isUnavailable = result?.isUnavailable ?? false;
    final title = isUnavailable ? 'Sistema indisponível' : 'Acesso negado';
    final detail = result?.message ?? 'Acesso não autorizado.';

    return Scaffold(
      key: const Key('view_state_denied'),
      backgroundColor: const Color(0xFFC4152F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUnavailable ? Icons.cloud_off : Icons.cancel,
                  size: 112,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Viewfinder com integração de câmera frontal ao vivo e varredura laser animada (US-16, US-17, US-19).
class FaceCameraViewfinder extends StatefulWidget {
  final int ramCount;
  final String thresholdPct;
  final bool isSyncing;
  final Future<void> Function(List<int> bytes)? onPhotoCaptured;
  final VoidCallback? onFallbackTriggered;

  const FaceCameraViewfinder({
    super.key,
    required this.ramCount,
    required this.thresholdPct,
    required this.isSyncing,
    this.onPhotoCaptured,
    this.onFallbackTriggered,
  });

  @override
  State<FaceCameraViewfinder> createState() => FaceCameraViewfinderState();
}

class FaceCameraViewfinderState extends State<FaceCameraViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scanAnimation;
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  bool get isCapturing => _isCapturing;

  Future<void> captureAndValidate() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        if (widget.onPhotoCaptured != null) {
          await widget.onPhotoCaptured!(bytes);
        }
      } else {
        widget.onFallbackTriggered?.call();
      }
    } catch (_) {
      widget.onFallbackTriggered?.call();
    }

    if (mounted) {
      setState(() => _isCapturing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _initFrontCamera();
  }

  Future<void> _initFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Procura preferencialmente a câmera frontal (selfie)
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });
    } catch (_) {
      // Fallback gracioso para ambientes de teste, emuladores ou sem permissão
      if (mounted) {
        setState(() => _isCameraReady = false);
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF14171D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF14171D), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Feed de Câmera Frontal ao Vivo ou Fundo Simulado (US-16)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _isCameraReady && _cameraController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ??
                            100,
                        height: _cameraController!.value.previewSize?.width ??
                            100,
                        child: CameraPreview(_cameraController!),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.1),
                          radius: 0.9,
                          colors: [Color(0xFF232A34), Color(0xFF14171D)],
                        ),
                      ),
                    ),
            ),
          ),

          // Máscara semitransparente escurecendo os cantos e destacando o enquadramento
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Moldura oval guia para alinhamento da face (US-16)
          Container(
            width: 170,
            height: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(85),
              border: Border.all(
                color: const Color(0xFF2ECC71),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(85),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isCameraReady)
                    const Center(
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 88,
                        color: Colors.white24,
                      ),
                    ),
                  // Linha animada de laser de varredura biométrica (US-16, US-17)
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, _) {
                      return Positioned(
                        top: 230 * _scanAnimation.value - 2,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2ECC71)
                                    .withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Indicador de nível de iluminação no canto superior (US-19)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF14171D).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD3DAE4).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wb_sunny, color: Colors.amberAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Iluminação ideal',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Indicador de modo local e limiar no canto superior direito
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF14171D).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD3DAE4).withValues(alpha: 0.3)),
              ),
              child: Text(
                'Limiar: ${widget.thresholdPct}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // Indicador de status de embeddings sincronizados em RAM (US-15)
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF14171D).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory, color: Color(0xFF2ECC71), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    widget.isSyncing
                        ? 'Sincronizando biometrias...'
                        : '${widget.ramCount} biometrias ativas em RAM',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
