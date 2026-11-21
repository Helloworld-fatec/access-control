import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/routes.dart';
import '../../core/session/session_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/warning_stripe.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  (String?, String?)? _photoSession;
  Future<Uint8List?>? _photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    final credentials = (session.backendUrl, session.token);
    if (credentials == _photoSession) return;
    _photoSession = credentials;
    _photo = session.authenticated ? session.loadProfilePhoto() : null;
  }

  void _logout(BuildContext context) => SessionScope.of(context).logout();

  void _openDoor(BuildContext context) =>
      Navigator.pushNamed(context, Routes.qrScanner);

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.user?['name'] as String?;
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
                    Row(
                      children: [
                        _avatar(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name == null || name.isEmpty
                                ? 'Olá!'
                                : 'Olá, $name!',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toque no botão e aponte a câmera para o QR Code da porta.',
                      style: TextStyle(color: AppColors.secondary, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Abrir porta. Ler QR Code',
                        child: Material(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(28),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => _openDoor(context),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 120,
                                  color: AppColors.white,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'ABRIR PORTA',
                                  style: TextStyle(
                                    color: AppColors.white,
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

  Widget _avatar() {
    const placeholder = CircleAvatar(
      radius: 28,
      child: Icon(Icons.person_outline, semanticLabel: 'Foto indisponível'),
    );
    return FutureBuilder<Uint8List?>(
      key: ObjectKey(_photo),
      future: _photo,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return placeholder;
        return ClipOval(
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            semanticLabel: 'Foto do perfil',
            errorBuilder: (_, _, _) => placeholder,
          ),
        );
      },
    );
  }
}
