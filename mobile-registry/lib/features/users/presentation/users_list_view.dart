import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/status_message.dart';
import '../application/users_list_controller.dart';
import '../data/user_models.dart';
import 'user_card.dart';

/// Lista de usuários com busca, filtros e "carregar mais" (US-06).
class UsersListView extends ConsumerStatefulWidget {
  const UsersListView({super.key});

  @override
  ConsumerState<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends ConsumerState<UsersListView> {
  static const Duration _searchDelay = Duration(milliseconds: 400);

  final _search = TextEditingController();
  Timer? _debounce;

  /// Os filtros ficam recolhidos para a lista aparecer logo; o resumo do que
  /// está aplicado fica sempre visível no botão "Filtros".
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(usersListProvider).search;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() {}); // mostra/esconde o botão de limpar
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      ref.read(usersListProvider.notifier).setSearch(text);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(usersListProvider.notifier).setSearch('');
  }

  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(usersListProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersListProvider);
    final controller = ref.read(usersListProvider.notifier);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Espaço no fim para o botão flutuante não cobrir o último cartão.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          _header(state, controller),
          const SizedBox(height: 16),
          ..._body(state, controller),
        ],
      ),
    );
  }

  /// Ex.: "Condômino | Inativos", ou "Nenhum filtro aplicado".
  String _filtersSummary(UsersListState state) {
    final parts = <String>[
      if (state.role != null) state.role!.label,
      if (state.active != null) state.active! ? 'Ativos' : 'Inativos',
    ];
    return parts.isEmpty ? 'Nenhum filtro aplicado' : parts.join(' | ');
  }

  Widget _header(UsersListState state, UsersListController controller) {
    final theme = Theme.of(context).textTheme;
    final hasChipFilters = state.role != null || state.active != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) {
            _debounce?.cancel();
            controller.setSearch(text);
          },
          decoration: InputDecoration(
            labelText: 'Buscar por nome ou documento',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _FiltersToggle(
          summary: _filtersSummary(state),
          highlighted: hasChipFilters,
          open: _filtersOpen,
          onTap: () => setState(() => _filtersOpen = !_filtersOpen),
        ),
        if (_filtersOpen) ...[
          const SizedBox(height: 16),
          Text('Perfil', style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Todos',
                selected: state.role == null,
                onSelected: () => controller.setRole(null),
              ),
              for (final role in UserRole.values)
                _FilterChip(
                  label: role.label,
                  selected: state.role == role,
                  onSelected: () => controller.setRole(role),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Situação', style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Todas',
                selected: state.active == null,
                onSelected: () => controller.setActive(null),
              ),
              _FilterChip(
                label: 'Ativos',
                selected: state.active == true,
                onSelected: () => controller.setActive(true),
              ),
              _FilterChip(
                label: 'Inativos',
                selected: state.active == false,
                onSelected: () => controller.setActive(false),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _body(UsersListState state, UsersListController controller) {
    // Primeira carga (ou filtro novo): lista vazia e carregando.
    if (state.loading && state.items.isEmpty) {
      return const [_LoadingBlock()];
    }

    // Erro sem nada para mostrar.
    if (state.error != null && state.items.isEmpty) {
      return [
        StatusMessage(kind: StatusKind.error, message: state.error!),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: 'Tentar novamente',
          icon: Icons.refresh,
          onPressed: controller.load,
        ),
      ];
    }

    // Lista vazia.
    if (state.items.isEmpty) {
      return [
        _EmptyBlock(
          hasFilters: state.hasFilters,
          onClearFilters: _clearAll,
        ),
      ];
    }

    return [
      if (state.error != null) ...[
        StatusMessage(kind: StatusKind.error, message: state.error!),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: 'Tentar novamente',
          icon: Icons.refresh,
          onPressed: controller.load,
        ),
        const SizedBox(height: 16),
      ],
      Semantics(
        liveRegion: true,
        child: Text(
          state.total == 1 ? '1 usuário' : '${state.total} usuários',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      const SizedBox(height: 8),
      for (final user in state.items) ...[
        UserCard(
          user: user,
          onTap: () => context.push(AppRoutes.userDetail(user.id)),
        ),
        const SizedBox(height: 12),
      ],
      if (state.moreError != null) ...[
        StatusMessage(kind: StatusKind.error, message: state.moreError!),
        const SizedBox(height: 12),
      ],
      if (state.hasMore)
        AppSecondaryButton(
          label: 'Carregar mais',
          icon: Icons.expand_more,
          isLoading: state.loadingMore,
          onPressed: controller.loadMore,
        ),
    ];
  }
}

/// Botão que abre e fecha os filtros e mostra o resumo do que está aplicado.
class _FiltersToggle extends StatelessWidget {
  const _FiltersToggle({
    required this.summary,
    required this.highlighted,
    required this.open,
    required this.onTap,
  });

  final String summary;
  final bool highlighted;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Filtros, ${open ? 'abertos' : 'fechados'}. $summary',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.support,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primary,
            width: highlighted ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtros',
                          style: theme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          summary,
                          style: theme.bodyMedium?.copyWith(
                            color: highlighted
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight:
                                highlighted ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: AppColors.onDark,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.support,
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      labelStyle: theme.bodyMedium?.copyWith(
        color: selected ? AppColors.onDark : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      onSelected: (_) => onSelected(),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Carregando usuários',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 4),
            const SizedBox(height: 16),
            Text(
              'Carregando usuários...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.hasFilters, required this.onClearFilters});

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.people_outline, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum usuário encontrado.',
              style: theme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Tente outra busca ou limpe os filtros.'
                  : 'Toque em "Novo usuário" para cadastrar o primeiro.',
              style: theme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              AppSecondaryButton(
                label: 'Limpar filtros',
                icon: Icons.filter_alt_off,
                onPressed: onClearFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
