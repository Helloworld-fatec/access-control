import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/settings_providers.dart';
import 'core/error/global_error_handler.dart';
import 'core/network/token_store.dart';
import 'core/storage/secure_store.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();

  final prefs = await SharedPreferences.getInstance();

  // Restaura a sessão guardada de forma segura (se existir). Assim o app abre
  // direto na área do administrador, sem piscar a tela de login.
  final secureStore = FlutterSecureKeyValueStore();
  final restoredUser = await SessionStorage(
    store: secureStore,
    tokens: SecureTokenStore(secureStore),
  ).restore();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(secureStore),
        initialAuthUserProvider.overrideWithValue(restoredUser),
      ],
      child: const AccessRegistryApp(),
    ),
  );
}
