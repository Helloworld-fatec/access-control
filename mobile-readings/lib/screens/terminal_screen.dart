import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/nfc_service.dart';
import '../state/terminal_controller.dart';
import 'settings_screen.dart';

/// Tela principal do Terminal de Acesso (US-04, US-07, US-08, US-09, US-11, US-12, US-13, US-20).
/// Reflete diretamente o estado atual do [TerminalController].
class TerminalScreen extends StatelessWidget {
  final TerminalController controller;

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

  /// Barra discreta de status (MQTT e acesso às configurações) (US-02, US-05).
  PreferredSizeWidget _buildStatusBar(
    BuildContext context, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final mqttOnline = controller.isMqttConnected;
    final simMode = controller.config.simulationMode;

    String connLabel;
    if (simMode) {
      connLabel = 'MODO SIMULAÇÃO';
    } else if (mqttOnline) {
      connLabel = 'MQTT: Conectado';
    } else if (controller.isFallbackPollingActive) {
      connLabel = 'MQTT: Offline (Polling HTTP ativo)';
    } else {
      connLabel = 'MQTT: Desconectado';
    }

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      title: Row(
        children: [
          Icon(
            mqttOnline || simMode ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: foregroundColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${controller.config.terminalId} · $connLabel',
              style: TextStyle(fontSize: 13, color: foregroundColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
      backgroundColor: const Color(0xFF0A0E12),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFF0A0E12),
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
                color: Colors.white54,
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
                child: OutlinedButton.icon(
                  key: const Key('btn_wake_terminal'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  onPressed: controller.onPresenceDetected,
                  icon: const Icon(Icons.touch_app),
                  label: const Text(
                    'Ativar terminal manualmente',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('btn_run_e2e_demo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF31566A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      controller.isE2eDemoRunning ? null : controller.runE2eDemo,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(
                    controller.isE2eDemoRunning
                        ? (controller.e2eDemoStep ?? 'Executando ensaio...')
                        : 'Ensaio E2E Completo (US-22)',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado 2: Escuta — exibe o QR Code rotativo, leitura NFC e reconhecimento facial (US-07, US-08, US-09, US-16, US-17, US-19, US-20).
  Widget _buildListeningView(BuildContext context) {
    final qrToken = controller.currentQrToken;
    final qrUnavailable = controller.isQrUnavailable;
    final nfcStatus = controller.nfcHardwareStatus;
    final isFaceMode = controller.isFaceModeEnabled;

    return Scaffold(
      key: const Key('view_state_listening'),
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFF31566A),
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

                  // Banner de progresso do Ensaio E2E Automatizado (US-22)
                  if (controller.isE2eDemoRunning) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF80DEEA)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.e2eDemoStep ??
                                  'Ensaio E2E em andamento...',
                              style: const TextStyle(
                                color: Color(0xFF006064),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Alternador entre métodos de entrada: QR/NFC vs Reconhecimento Facial (US-16)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.qr_code_2),
                        label: Text('QR Code & Cartão'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.face),
                        label: Text('Biometria Facial'),
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
                    _buildQrNfcView(context, qrToken, qrUnavailable, nfcStatus),

                  if (controller.statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFB51F2E)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.statusMessage!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFB51F2E),
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
            color: Color(0xFF31566A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Olhe diretamente para a câmera para validar seu acesso.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Moldura Viewfinder com Varredura Laser Animada (US-16, US-17, US-19)
        FaceCameraViewfinder(
          ramCount: ramCount,
          thresholdPct: thresholdPct,
          isSyncing: controller.isFaceSyncLoading,
        ),

        const SizedBox(height: 16),

        // Botões de Ação e Simulação Facial (US-17, US-18, US-19)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('btn_sim_face_valid'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: controller.simulateFaceAccess,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Identificar Face Autorizada'),
            ),
            OutlinedButton.icon(
              key: const Key('btn_sim_face_denied'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB51F2E),
                side: const BorderSide(color: Color(0xFFB51F2E)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: controller.simulateFaceAccessDenied,
              icon: const Icon(Icons.highlight_off),
              label: const Text('Face Não Cadastrada'),
            ),
            OutlinedButton.icon(
              key: const Key('btn_sim_face_low_light'),
              onPressed: controller.simulateFaceLowLight,
              icon: const Icon(Icons.nightlight_round),
              label: const Text('Testar Luz Fraca (US-19)'),
            ),
            IconButton.filledTonal(
              tooltip: 'Ressincronizar biometrias locais',
              icon: const Icon(Icons.sync),
              onPressed: controller.syncFaceEmbeddings,
            ),
          ],
        ),
      ],
    );
  }

  /// Painel de QR Code e Leitura NFC (US-07, US-08, US-09).
  Widget _buildQrNfcView(
    BuildContext context,
    dynamic qrToken,
    bool qrUnavailable,
    NfcHardwareStatus nfcStatus,
  ) {
    return Column(
      key: const Key('qr_nfc_view'),
      children: [
        const Text(
          'Identifique-se para entrar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF31566A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Aproxime sua tag NFC ou aponte a câmera para o QR Code.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Card do QR Code rotativo ou aviso de indisponibilidade (US-07, US-08)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF31566A),
              width: 2,
            ),
          ),
          child: qrUnavailable || qrToken == null
              ? Column(
                  key: const Key('qr_unavailable_box'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2,
                      size: 72,
                      color: Color(0xFFB51F2E),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'QR indisponível',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB51F2E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sem comunicação com o servidor para atualizar o código.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('btn_retry_qr'),
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
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // Indicador do estado do leitor NFC (US-09)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EBEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                nfcStatus == NfcHardwareStatus.available
                    ? Icons.nfc
                    : Icons.portable_wifi_off,
                size: 32,
                color: nfcStatus == NfcHardwareStatus.available
                    ? const Color(0xFF31566A)
                    : const Color(0xFFB51F2E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nfcStatus == NfcHardwareStatus.available
                      ? 'Leitor NFC ativo: aproxime seu cartão ou chaveiro do aparelho.'
                      : 'NFC desligado ou indisponível neste aparelho.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controles auxiliares quando o Modo de Simulação estiver ativo ou sem hardware NFC
        if (controller.config.simulationMode ||
            nfcStatus != NfcHardwareStatus.available) ...[
          const SizedBox(height: 18),
          const Divider(),
          const Text(
            'Simulação de Leitura NFC (Modo de Teste)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('btn_sim_nfc_valid'),
                onPressed: () => controller.onNfcTagRead('04A1B2C3D4'),
                icon: const Icon(Icons.check),
                label: const Text('Simular Tag Autorizada'),
              ),
              OutlinedButton.icon(
                key: const Key('btn_sim_nfc_invalid'),
                onPressed: () => controller.onNfcTagRead('00000000'),
                icon: const Icon(Icons.close),
                label: const Text('Simular Tag Negada'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Estado 3: Validando — aguarda resposta do backend (US-10).
  Widget _buildValidatingView(BuildContext context) {
    return Scaffold(
      key: const Key('view_state_validating'),
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: _buildStatusBar(
        context,
        backgroundColor: const Color(0xFF31566A),
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
                child: CircularProgressIndicator(strokeWidth: 6),
              ),
              SizedBox(height: 24),
              Text(
                'Validando credencial...',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31566A),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Aguarde um instante.',
                style: TextStyle(fontSize: 18, color: Colors.black87),
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
      backgroundColor: const Color(0xFF2E7D32),
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
                  color: Colors.white,
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open, color: Colors.white, size: 28),
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
      backgroundColor: const Color(0xFFB51F2E),
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

/// Viewfinder simulado com varredura laser animada em tempo real (US-16, US-17, US-19).
class FaceCameraViewfinder extends StatefulWidget {
  final int ramCount;
  final String thresholdPct;
  final bool isSyncing;

  const FaceCameraViewfinder({
    super.key,
    required this.ramCount,
    required this.thresholdPct,
    required this.isSyncing,
  });

  @override
  State<FaceCameraViewfinder> createState() => _FaceCameraViewfinderState();
}

class _FaceCameraViewfinderState extends State<FaceCameraViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scanAnimation;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2129),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF31566A), width: 3),
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
          // Fundo simulando captura de câmera
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.1),
                    radius: 0.9,
                    colors: [Color(0xFF2C394B), Color(0xFF0F141C)],
                  ),
                ),
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
                color: const Color(0xFF4DD0E1),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.2),
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
                            color: const Color(0xFF4DD0E1),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4DD0E1)
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
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
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
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
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
                color: const Color(0xFF31566A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory, color: Colors.white, size: 14),
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
