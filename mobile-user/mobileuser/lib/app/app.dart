import 'package:flutter/material.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_scope.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/authorizations/authorizations_page.dart';
import '../features/home/home_page.dart';
import '../features/qr/qr_scanner_page.dart';
import 'routes.dart';

class MobileUserApp extends StatefulWidget {
  const MobileUserApp({super.key});
  @override
  State<MobileUserApp> createState() => _MobileUserAppState();
}

class _MobileUserAppState extends State<MobileUserApp> {
  late final SessionController session;
  @override
  void initState() {
    super.initState();
    session = SessionController();
    session.restore();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: MaterialApp(
      title: 'Access Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: {
        Routes.authorizations: (_) => AnimatedBuilder(
          animation: session,
          builder: (context, _) => session.authenticated
              ? const AuthorizationsPage()
              : const LoginPage(),
        ),
        Routes.qrScanner: (_) => AnimatedBuilder(
          animation: session,
          builder: (context, _) =>
              session.authenticated ? const QrScannerPage() : const LoginPage(),
        ),
      },
      home: AnimatedBuilder(
        animation: session,
        builder: (context, _) {
          if (session.initializing)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          return session.authenticated ? const HomePage() : const LoginPage();
        },
      ),
    ),
  );
}
