import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

/// Teste de fumaça: o app inicia sem erros.
void main() {
  testWidgets('app inicia e mostra a tela inicial', (tester) async {
    final env = await buildTestEnv(tester);
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Registro de Acesso'), findsWidgets);
  });
}
