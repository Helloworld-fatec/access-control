import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/authorizations/authorizations_page.dart';
import '../features/home/home_page.dart';
import 'routes.dart';

class MobileUserApp extends StatelessWidget {
  const MobileUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Access Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: Routes.login,
      routes: {
        Routes.login: (_) => const LoginPage(),
        Routes.home: (_) => const HomePage(),
        Routes.authorizations: (_) => const AuthorizationsPage(),
      },
    );
  }
}
