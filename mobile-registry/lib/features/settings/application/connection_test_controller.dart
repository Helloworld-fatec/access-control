import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/connection_repository.dart';

enum ConnectionStatus { idle, loading, success, failure }

class ConnectionTestState {
  const ConnectionTestState(this.status, [this.message = '']);

  const ConnectionTestState.idle() : this(ConnectionStatus.idle);

  final ConnectionStatus status;
  final String message;
}

class ConnectionTestNotifier extends Notifier<ConnectionTestState> {
  static const String successMessage = 'Conexão com o servidor funcionando.';

  @override
  ConnectionTestState build() => const ConnectionTestState.idle();

  void reset() => state = const ConnectionTestState.idle();

  Future<void> run() async {
    if (state.status == ConnectionStatus.loading) return;
    state = const ConnectionTestState(ConnectionStatus.loading);
    try {
      await ref.read(connectionRepositoryProvider).check();
      state = const ConnectionTestState(
        ConnectionStatus.success,
        successMessage,
      );
    } catch (e) {
      state = ConnectionTestState(ConnectionStatus.failure, userMessageFor(e));
    }
  }
}

final connectionTestProvider =
    NotifierProvider<ConnectionTestNotifier, ConnectionTestState>(
  ConnectionTestNotifier.new,
);
