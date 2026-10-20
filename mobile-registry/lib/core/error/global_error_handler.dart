import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tratamento global de erros (US-01): nada fecha o app em silêncio e, em
/// produção, uma falha de tela mostra uma mensagem simples em vez da tela vermelha.
void installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Ponto único para, no futuro, enviar a um serviço de monitoramento.
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Erro não tratado: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const FriendlyErrorWidget();
  };
}

class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF7F7F4),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Algo deu errado nesta tela. Volte e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF1B2A33),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
