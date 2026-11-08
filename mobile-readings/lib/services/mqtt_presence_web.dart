import '../config/terminal_config.dart';
import 'mqtt_presence_service.dart';

PresenceMqttService createPlatformMqttService() => WebFallbackMqttService();

/// Fallback seguro para quando o app é executado no navegador (Chrome/Edge) durante desenvolvimento,
/// onde sockets TCP brutos na porta 1883 não estão disponíveis (usa o fallback HTTP ou Modo Simulação).
class WebFallbackMqttService implements PresenceMqttService {
  @override
  bool get isConnected => false;

  @override
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    onConnectionChanged(false);
  }

  @override
  Future<void> disconnect() async {}
}
