import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config/terminal_config.dart';
import 'mqtt_presence_service.dart';

PresenceMqttService createPlatformMqttService() => MosquittoPresenceService();

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
    void Function(bool isBusy)? onReaderBusyChanged,
  }) async {
    await disconnect();

    if (config.simulationMode || config.mqttHost.trim().isEmpty) {
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

      final presenceTopic = config.mqttPresenceTopic;
      final writingTopic = config.mqttNfcWritingTopic;

      client.subscribe(presenceTopic, MqttQos.atLeastOnce);
      client.subscribe(writingTopic, MqttQos.atLeastOnce);

      _subscription = client.updates?.listen((messages) {
        for (final msg in messages) {
          final recMess = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );

          if (msg.topic == presenceTopic) {
            if (_isPresencePayloadActive(payload)) {
              onPresenceDetected();
            }
          } else if (msg.topic == writingTopic) {
            final isBusy = _isWritingPayloadBusy(payload);
            onReaderBusyChanged?.call(isBusy);
          }
        }
      });
    } else {
      _connected = false;
      onConnectionChanged(false);
    }
  }

  /// Interpreta payload do tópico de gravação de tag NFC (US-10).
  static bool _isWritingPayloadBusy(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower == '1' || lower == 'true' || lower == 'busy' || lower == 'writing') {
      return true;
    }
    if (lower == '0' || lower == 'false' || lower == 'idle') {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        if (decoded.containsKey('busy')) {
          return decoded['busy'] == true || decoded['busy'] == 1;
        }
        if (decoded.containsKey('writing')) {
          return decoded['writing'] == true || decoded['writing'] == 1;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Interpreta o payload publicado pelo ESP32 em `terminal/{id}/presence`.
  static bool _isPresencePayloadActive(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (trimmed.isEmpty) return true;
    final lower = trimmed.toLowerCase();
    if (lower == '1' ||
        lower == 'true' ||
        lower == 'presence' ||
        lower == 'active') {
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
