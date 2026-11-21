import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/terminal_config.dart';
import 'screens/terminal_screen.dart';
import 'services/api_client.dart';
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

  const configStorage = LocalConfigStorage();
  const initialConfig = TerminalConfig();
  final apiClient = TerminalApiClient(config: initialConfig);

  final controller = TerminalController(
    configStorage: configStorage,
    apiClient: apiClient,
  );

  // Renderiza a interface imediatamente, sem travar a abertura com I/O de rede ou disco
  runApp(MobileReadingsApp(controller: controller));

  unawaited(controller.initialize());
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
        scaffoldBackgroundColor: const Color(0xFFECF0F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD81E3F),
          primary: const Color(0xFFD81E3F),
          secondary: const Color(0xFF14171D),
          surface: const Color(0xFFECF0F5),
        ),
        useMaterial3: true,
      ),
      home: TerminalScreen(controller: controller),
    );
  }
}
