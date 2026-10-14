import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/warning_stripe.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _logout(BuildContext context) {
    // MOCK: depois, limpar token do flutter_secure_storage.
    Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
  }

  void _openDoor(BuildContext context) {
    // MOCK: depois, abrir a tela de leitura do QR (mobile_scanner).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leitura do QR Code em breve')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            iconSize: 30,
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const WarningStripe(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Olá!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toque no botão e aponte a câmera para o QR Code da porta.',
                      style: TextStyle(color: AppColors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Abrir porta. Ler QR Code',
                        child: Material(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => _openDoor(context),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded,
                                    size: 120, color: AppColors.black),
                                SizedBox(height: 16),
                                Text(
                                  'ABRIR PORTA',
                                  style: TextStyle(
                                    color: AppColors.black,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.authorizations),
                      icon: const Icon(Icons.badge_outlined, size: 28),
                      label: const Text('MINHAS AUTORIZAÇÕES'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
