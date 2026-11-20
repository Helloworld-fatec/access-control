import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/users/presentation/new_user_wizard_screen.dart';
import '../../features/users/presentation/user_form_screen.dart';
import '../widgets/app_buttons.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String settings = '/settings';
  static const String userNew = '/users/new';

  /// Detalhe e edição de um usuário.
  static String userDetail(String id) => '/users/$id';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Avisa o roteador quando entra ou sai alguém, para reavaliar o redirect.
  final authChanges = ValueNotifier<int>(0);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final path = state.matchedLocation;

      // A configuração é acessível ANTES do login (US-02): sem ela não há
      // como apontar o app para o servidor.
      if (path == AppRoutes.settings) return null;

      if (!loggedIn) return path == AppRoutes.login ? null : AppRoutes.login;
      if (path == AppRoutes.login) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      // '/users/new' precisa vir antes de '/users/:id'.
      GoRoute(
        path: AppRoutes.userNew,
        builder: (context, state) => const NewUserWizardScreen(),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (context, state) =>
            UserFormScreen(userId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );

  ref.listen<AuthState>(authProvider, (previous, next) {
    authChanges.value++;
    final wasLoggedIn = previous?.isAuthenticated ?? false;
    if (wasLoggedIn && !next.isAuthenticated) {
      // Sessão encerrada (Sair ou 401): `go` DESCARTA a pilha de telas.
      // Só o redirect não bastaria: ele não roda ao voltar (pop) de
      // Configurações para uma tela protegida que ficou embaixo.
      router.go(AppRoutes.login);
    }
  });

  ref.onDispose(() {
    router.dispose();
    authChanges.dispose();
  });
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página não encontrada')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Não encontramos esta página.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: 'Voltar ao início',
                icon: Icons.home,
                onPressed: () => context.go(AppRoutes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
