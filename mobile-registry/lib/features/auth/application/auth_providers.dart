import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/secure_store.dart';
import '../data/auth_repository.dart';
import '../data/auth_user.dart';
import '../data/session_storage.dart';

/// Administrador restaurado do armazenamento seguro ao abrir o app.
/// Sobrescrito no `main()`; `null` significa "ninguém logado".
final initialAuthUserProvider = Provider<AuthUser?>((ref) => null);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(
    store: ref.watch(secureStoreProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.watch(dioProvider),
    session: ref.watch(sessionStorageProvider),
  ),
);

/// Por que a sessão terminou (para a tela de login explicar ao usuário).
enum SessionEndReason {
  /// O próprio usuário tocou em "Sair".
  signedOut,

  /// O servidor recusou o token (401): ele expirou ou deixou de valer.
  expired,
}

class AuthState {
  const AuthState({this.user, this.endReason});

  final AuthUser? user;

  /// Preenchido só depois que uma sessão termina; `null` ao entrar.
  final SessionEndReason? endReason;

  bool get isAuthenticated => user != null;
}

/// Quem está logado agora. O roteador escuta este estado para decidir
/// entre a tela de login e as telas protegidas.
///
/// Também é o ponto único que encerra a sessão: pelo botão "Sair" ou quando
/// o servidor responde 401 a uma chamada autenticada, em qualquer tela.
class AuthNotifier extends Notifier<AuthState> {
  bool _ending = false;

  @override
  AuthState build() {
    // Tratamento global de sessão expirada (RNF de segurança): qualquer 401
    // de uma chamada autenticada chega aqui, venha de onde vier.
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      unawaited(_onSessionExpired());
    });
    return AuthState(user: ref.watch(initialAuthUserProvider));
  }

  void signedIn(AuthUser user) => state = AuthState(user: user);

  /// Botão "Sair": apaga token e perfil do armazenamento seguro e volta ao login.
  Future<void> signOut() => _endSession(SessionEndReason.signedOut);

  Future<void> _onSessionExpired() async {
    if (!state.isAuthenticated) return; // nada a encerrar

    final sentToken = ref.read(sessionExpiredProvider.notifier).lastSentToken;
    if (sentToken != null) {
      String? currentToken;
      try {
        currentToken = await ref.read(tokenStoreProvider).read();
      } catch (_) {
        currentToken = null; // não deu para ler: tratamos como sessão inválida
      }
      if (!ref.mounted || !state.isAuthenticated) return; // terminou enquanto líamos
      // 401 atrasado de uma sessão anterior: a sessão atual não tem nada a ver.
      if (currentToken != null && currentToken != sentToken) return;
    }
    await _endSession(SessionEndReason.expired);
  }

  Future<void> _endSession(SessionEndReason reason) async {
    if (_ending || !state.isAuthenticated) return;
    _ending = true;
    try {
      // Primeiro apaga os segredos; só depois o app "sai". Assim um novo login
      // feito logo em seguida nunca é apagado por uma limpeza atrasada.
      try {
        await ref.read(sessionStorageProvider).clear();
      } catch (e) {
        // Mesmo que o aparelho falhe ao apagar, o usuário sai da área logada.
        debugPrint('Falha ao limpar a sessão: $e');
      }
      // O app pode ter descartado este provider durante a limpeza (ex.: testes).
      if (!ref.mounted) return;
      state = AuthState(endReason: reason);
    } finally {
      _ending = false;
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class LoginState {
  const LoginState({this.loading = false, this.error});

  final bool loading;
  final String? error;
}

/// Orquestra o envio do formulário de login.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> submit({required String email, required String password}) async {
    if (state.loading) return; // evita toques repetidos
    state = const LoginState(loading: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      if (!ref.mounted) return;
      ref.read(authProvider.notifier).signedIn(user);
      state = const LoginState();
    } catch (e) {
      if (!ref.mounted) return;
      state = LoginState(error: userMessageFor(e));
    }
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
  LoginController.new,
);
