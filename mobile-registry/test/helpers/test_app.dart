import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/app.dart';
import 'package:mobile_registry/core/config/settings_providers.dart';
import 'package:mobile_registry/core/network/network_providers.dart';
import 'package:mobile_registry/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_adapter.dart';

class TestEnv {
  TestEnv(this.prefs, this.adapter, this.widget);
  final SharedPreferences prefs;
  final FakeAdapter adapter;
  final Widget widget;
}

/// Monta o app (ou apenas [home]) com armazenamento e rede falsos.
Future<TestEnv> buildTestEnv(
  WidgetTester tester, {
  Widget? home,
  FakeAdapter? adapter,
  Map<String, Object> initialPrefs = const {},
}) async {
  // Ajuste correto para dimensões lógicas visíveis nos testes
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  final fake = adapter ??
      FakeAdapter([
        FakeAdapter.json(200, {'status': 'ok'}),
      ]);

  final widget = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      httpClientAdapterProvider.overrideWithValue(fake),
      retryDelayProvider.overrideWithValue((_) => Duration.zero),
    ],
    child: home == null
        ? const AccessRegistryApp()
        : MaterialApp(theme: AppTheme.light(), home: home),
  );
  return TestEnv(prefs, fake, widget);
}

/// Rola até o item e toca nele.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}