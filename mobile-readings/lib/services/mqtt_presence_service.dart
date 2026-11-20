import '../config/terminal_config.dart';
import 'mqtt_presence_io.dart'
    if (dart.library.js_interop) 'mqtt_presence_web.dart';

/// Interface do serviço de presença MQTT para permitir substituição em testes (US-05).
abstract class PresenceMqttService {
  bool get isConnected;
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
  });
  Future<void> disconnect();

  factory PresenceMqttService() => createPlatformMqttService();
}
