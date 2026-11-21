import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/application/session_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/terminals/data/terminals_repository.dart';
import 'features/users/data/face_camera.dart';
import 'features/users/data/users_repository.dart';

class AccessRegistryApp extends StatefulWidget {
  const AccessRegistryApp({
    super.key,
    this.session,
    this.capturePhoto = captureFacePhoto,
  });

  final SessionController? session;
  final FacePhotoCapture capturePhoto;

  @override
  State<AccessRegistryApp> createState() => _AccessRegistryAppState();
}

class _AccessRegistryAppState extends State<AccessRegistryApp> {
  late final _session = widget.session ?? SessionController();
  late final _users = UsersRepository(_session.dio);
  late final _terminals = TerminalsRepository(_session.dio);

  @override
  void dispose() {
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final signedIn = _session.isAuthenticated;
        return MaterialApp(
          // Trocar de sessão descarta a pilha de telas, inclusive formulários.
          key: ValueKey(signedIn),
          title: 'Registro de Acesso',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: signedIn
              ? HomeScreen(
                  repository: _users,
                  terminalsRepository: _terminals,
                  capturePhoto: widget.capturePhoto,
                  onSignOut: _session.signOut,
                )
              : LoginScreen(session: _session),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
