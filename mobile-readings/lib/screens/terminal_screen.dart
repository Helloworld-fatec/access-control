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
            ],
          ),
        ),
      ),
    );
  }

  /// Estado 2: Escuta — exibe o QR Code rotativo e aguarda leitura NFC (US-07, US-08, US-09, US-20).
  Widget _buildListeningView(BuildContext context) {
    final qrToken = controller.currentQrToken;
    final qrUnavailable = controller.isQrUnavailable;
    final nfcStatus = controller.nfcHardwareStatus;

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
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Identifique-se para entrar',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF31566A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Leia o QR Code com o aplicativo ou aproxime sua tag NFC.',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Card do QR Code ou aviso de indisponibilidade (US-07, US-08)
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (controller.statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      controller.statusMessage!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFB51F2E),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Controles auxiliares quando o Modo de Simulação estiver ativo
                  if (controller.config.simulationMode) ...[
                    const SizedBox(height: 20),
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
                          onPressed: () =>
                              controller.onNfcTagRead('04A1B2C3D4'),
                          icon: const Icon(Icons.check),
                          label: const Text('Simular Tag Autorizada'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('btn_sim_nfc_invalid'),
                          onPressed: () =>
                              controller.onNfcTagRead('00000000'),
                          icon: const Icon(Icons.close),
                          label: const Text('Simular Tag Negada'),
                        ),
                      ],
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
