import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/logout_action.dart';
import '../../terminals/data/terminals_repository.dart';
import '../../terminals/presentation/terminals_screen.dart';
import '../../users/application/users_list_controller.dart';
import '../../users/data/face_camera.dart';
import '../../users/data/users_repository.dart';
import '../../users/presentation/user_form_screen.dart';
import '../../users/presentation/users_list_view.dart';

/// Área do administrador: lista, cadastro de usuários e logout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.terminalsRepository,
    required this.capturePhoto,
    required this.onSignOut,
  });

  final UsersRepository repository;
  final TerminalsRepository terminalsRepository;
  final FacePhotoCapture capturePhoto;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _controller = UsersListController(widget.repository);

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openForm([String? id]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          userId: id,
          repository: widget.repository,
          capturePhoto: widget.capturePhoto,
          onChanged: _controller.refresh,
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandedTitle('Usuários'),
        actions: [
          IconButton(
            tooltip: 'Terminais',
            icon: const Icon(Icons.door_front_door_outlined),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      TerminalsScreen(repository: widget.terminalsRepository),
                ),
              );
            },
          ),
          LogoutAppBarAction(onSignOut: widget.onSignOut),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: UsersListView(controller: _controller, onOpen: _openForm),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo usuário'),
        onPressed: _openForm,
      ),
    );
  }
}
