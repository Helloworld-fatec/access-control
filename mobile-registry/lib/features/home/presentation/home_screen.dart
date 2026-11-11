import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/logout_action.dart';
import '../../users/presentation/users_list_view.dart';

/// Área do administrador: a lista de usuários, com acesso às configurações,
/// ao cadastro de novo usuário e ao botão Sair.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            iconSize: 28,
            tooltip: 'Configurações',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.onDark,
              minimumSize: const Size(56, 56),
            ),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const LogoutAppBarAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: const SafeArea(child: UsersListView()),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo usuário'),
        onPressed: () => context.push(AppRoutes.userNew),
      ),
    );
  }
}
