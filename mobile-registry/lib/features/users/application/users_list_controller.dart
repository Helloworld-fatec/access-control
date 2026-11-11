import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_providers.dart';
import '../data/user_models.dart';
import '../data/users_repository.dart';

/// Estado da listagem de usuários: itens, paginação, filtros e erros.
class UsersListState {
  const UsersListState({
    this.items = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.moreError,
    this.search = '',
    this.role,
    this.active,
  });

  final List<UserSummary> items;
  final int page;
  final int totalPages;
  final int total;

  /// Carregando a primeira página (ou recarregando).
  final bool loading;

  /// Carregando a próxima página.
  final bool loadingMore;

  /// Erro ao carregar a primeira página.
  final String? error;

  /// Erro ao carregar uma página seguinte.
  final String? moreError;

  final String search;
  final UserRole? role;

  /// `true` = só ativos, `false` = só inativos, `null` = todos.
  final bool? active;

  bool get hasMore => page < totalPages;
  bool get hasFilters => search.isNotEmpty || role != null || active != null;

  static const Object _keep = Object();

  UsersListState copyWith({
    List<UserSummary>? items,
    int? page,
    int? totalPages,
    int? total,
    bool? loading,
    bool? loadingMore,
    Object? error = _keep,
    Object? moreError = _keep,
    String? search,
    Object? role = _keep,
    Object? active = _keep,
  }) {
    return UsersListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: identical(error, _keep) ? this.error : error as String?,
      moreError:
          identical(moreError, _keep) ? this.moreError : moreError as String?,
      search: search ?? this.search,
      role: identical(role, _keep) ? this.role : role as UserRole?,
      active: identical(active, _keep) ? this.active : active as bool?,
    );
  }
}

/// Controla a lista de usuários (US-06): carrega, busca, filtra e pagina.
class UsersListController extends Notifier<UsersListState> {
  static const int pageSize = 20;

  /// Identifica a requisição "vigente". Respostas de requisições antigas
  /// (ex.: digitou outra busca antes da anterior responder) são descartadas.
  int _request = 0;

  @override
  UsersListState build() {
    // Ao trocar de sessão (login/logout) a lista começa do zero: nunca mostra
    // dados de outro administrador.
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    _request++;
    if (userId == null) return const UsersListState();

    Future<void>.microtask(() {
      if (ref.mounted) load();
    });
    return const UsersListState(loading: true);
  }

  /// Carrega a primeira página com os filtros atuais.
  Future<void> load() async {
    final id = ++_request;
    state = state.copyWith(loading: true, error: null, moreError: null);
    try {
      final page = await ref.read(usersRepositoryProvider).list(
            pageSize: pageSize,
            search: state.search,
            role: state.role,
            active: state.active,
          );
      if (!ref.mounted || id != _request) return;
      state = state.copyWith(
        items: page.items,
        page: page.page,
        totalPages: page.totalPages,
        total: page.total,
        loading: false,
      );
    } catch (e) {
      if (!ref.mounted || id != _request) return;
      state = state.copyWith(loading: false, error: userMessageFor(e));
    }
  }

  /// Recarrega mantendo filtros (puxar para atualizar, tentar de novo).
  Future<void> refresh() => load();

  /// Carrega a página seguinte e a acrescenta à lista.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final id = _request;
    state = state.copyWith(loadingMore: true, moreError: null);
    try {
      final next = await ref.read(usersRepositoryProvider).list(
            page: state.page + 1,
            pageSize: pageSize,
            search: state.search,
            role: state.role,
            active: state.active,
          );
      if (!ref.mounted || id != _request) return;
      final known = state.items.map((u) => u.id).toSet();
      state = state.copyWith(
        items: [
          ...state.items,
          ...next.items.where((u) => !known.contains(u.id)),
        ],
        page: next.page,
        totalPages: next.totalPages,
        total: next.total,
        loadingMore: false,
      );
    } catch (e) {
      if (!ref.mounted || id != _request) return;
      state = state.copyWith(loadingMore: false, moreError: userMessageFor(e));
    }
  }

  Future<void> setSearch(String text) {
    final term = text.trim();
    if (term == state.search) return Future<void>.value();
    return _applyFilters(search: term);
  }

  Future<void> setRole(UserRole? role) {
    if (role == state.role) return Future<void>.value();
    return _applyFilters(role: role, changeRole: true);
  }

  Future<void> setActive(bool? active) {
    if (active == state.active) return Future<void>.value();
    return _applyFilters(active: active, changeActive: true);
  }

  Future<void> clearFilters() {
    if (!state.hasFilters) return Future<void>.value();
    return _applyFilters(
      search: '',
      role: null,
      changeRole: true,
      active: null,
      changeActive: true,
    );
  }

  Future<void> _applyFilters({
    String? search,
    UserRole? role,
    bool changeRole = false,
    bool? active,
    bool changeActive = false,
  }) {
    // Esvazia a lista na hora: não mostra resultados do filtro anterior.
    state = state.copyWith(
      items: const [],
      page: 1,
      totalPages: 1,
      total: 0,
      search: search,
      role: changeRole ? role : state.role,
      active: changeActive ? active : state.active,
    );
    return load();
  }
}

final usersListProvider =
    NotifierProvider<UsersListController, UsersListState>(
  UsersListController.new,
);
