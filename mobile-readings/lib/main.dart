import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/terminal_config.dart';
import 'screens/terminal_screen.dart';
import 'services/api_client.dart';
import 'services/face_sync_service.dart';
import 'services/mqtt_presence_service.dart';
import 'state/terminal_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mantém a orientação vertical fixa e impede que a tela apague no terminal dedicado (US-14)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {}
  try {
    await WakelockPlus.enable();
  } catch (_) {}

  final configStorage = const LocalConfigStorage();
  final initialConfig = await configStorage.load();
  final apiClient = TerminalApiClient(config: initialConfig);
  final mqttService = PresenceMqttService();
  final faceService = FaceSyncService();

  final controller = TerminalController(
    configStorage: configStorage,
    apiClient: apiClient,
    mqttService: mqttService,
    faceService: faceService,
    initialConfig: initialConfig,
  );

  await controller.initialize();

  runApp(MobileReadingsApp(controller: controller));
}

class MobileReadingsApp extends StatelessWidget {
  final TerminalController controller;

  const MobileReadingsApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal de Acesso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF31566A),
          primary: const Color(0xFF31566A),
          secondary: const Color(0xFFB51F2E),
          surface: const Color(0xFFF7F7F4),
        ),
        useMaterial3: true,
      ),
      home: TerminalScreen(controller: controller),
    );
  }
}
