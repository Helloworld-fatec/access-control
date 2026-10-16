import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config/terminal_config.dart';

/// Interface do serviço de presença MQTT para permitir substituição em testes (US-05).
abstract class PresenceMqttService {
  bool get isConnected;
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
  });
  Future<void> disconnect();
}

/// Implementação MQTT TCP (porta 1883) assinando `terminal/{id}/presence` (US-05).
class MosquittoPresenceService implements PresenceMqttService {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect({
    required TerminalConfig config,
    required void Function() onPresenceDetected,
    required void Function(bool connected) onConnectionChanged,
  }) async {
    await disconnect();

    if (config.mqttHost.trim().isEmpty) {
      onConnectionChanged(false);
      return;
    }

    final clientId =
        'mobile_readings_${config.terminalId}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    final client = MqttServerClient.withPort(
      config.mqttHost.trim(),
      clientId,
      config.mqttPort,
    );

    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.connectTimeoutPeriod = 4000;

    client.onConnected = () {
      _connected = true;
      onConnectionChanged(true);
    };

    client.onDisconnected = () {
      _connected = false;
      onConnectionChanged(false);
    };

    client.onAutoReconnect = () {
      _connected = false;
      onConnectionChanged(false);
    };

    client.onAutoReconnected = () {
      _connected = true;
      onConnectionChanged(true);
    };

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMess;
    _client = client;

    try {
      if (config.mqttUsername.trim().isNotEmpty) {
        await client.connect(
          config.mqttUsername.trim(),
          config.mqttPassword,
        );
      } else {
        await client.connect();
      }
    } catch (_) {
      _connected = false;
      onConnectionChanged(false);
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      _connected = true;
      onConnectionChanged(true);
      final topic = config.mqttPresenceTopic;
      client.subscribe(topic, MqttQos.atLeastOnce);

      _subscription = client.updates?.listen((messages) {
        for (final msg in messages) {
          if (msg.topic != topic) continue;
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );
          if (_isPresencePayloadActive(payload)) {
            onPresenceDetected();
          }
        }
      });
    } else {
      _connected = false;
      onConnectionChanged(false);
    }
  }

  /// Interpreta o payload publicado pelo ESP32 em `terminal/{id}/presence`.
  static bool _isPresencePayloadActive(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    if (lower == '1' || lower == 'true' || lower == 'presence' || lower == 'active') {
      return true;
    }
    if (lower == '0' || lower == 'false' || lower == 'idle') {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        if (decoded.containsKey('presence')) {
          return decoded['presence'] == true || decoded['presence'] == 1;
        }
        if (decoded.containsKey('detected')) {
          return decoded['detected'] == true || decoded['detected'] == 1;
        }
      }
    } catch (_) {}
    return true;
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    _connected = false;
  }
}
