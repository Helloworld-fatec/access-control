import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileuser/app/app.dart';

void main() {
  testWidgets('Login aceita qualquer credencial e navega até as autorizações',
      (WidgetTester tester) async {
    // Tela de celular (360x800 lógicos) para nada ficar fora da área visível.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MobileUserApp());

    // Tela de login
    expect(find.text('Controle de Acesso'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);

    // Qualquer credencial entra.
    await tester.enterText(find.byType(TextField).at(0), 'qualquer');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tela inicial
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('ABRIR PORTA'), findsOneWidget);

    // Tela de autorizações
    await tester.tap(find.text('MINHAS AUTORIZAÇÕES'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas autorizações'), findsOneWidget);
    expect(find.text('Portaria Principal'), findsOneWidget);
  });
}