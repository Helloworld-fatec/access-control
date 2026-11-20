import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_registry/core/nfc/nfc_service.dart';
import 'package:mobile_registry/features/nfc/presentation/nfc_capture_dialog.dart';

import '../../helpers/fake_nfc_service.dart';
import '../../helpers/test_app.dart';

/// Tela com um botão que abre o diálogo e guarda o resultado.
class _Host extends StatelessWidget {
  const _Host({required this.onResult, this.title = 'Ler tag NFC'});

  final ValueChanged<String?> onResult;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => FilledButton(
            onPressed: () async =>
                onResult(await showNfcCaptureDialog(context, title: title)),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
  }
}

class CaptureResult {
  bool called = false;
  String? value;
  void call(String? v) {
    called = true;
    value = v;
  }
}

Future<void> open(
  WidgetTester tester,
  FakeNfcService nfc,
  CaptureResult result, {
  String title = 'Ler tag NFC',
}) async {
  final env = await buildTestEnv(
    tester,
    home: _Host(onResult: result.call, title: title),
    nfc: nfc,
    logicalSize: tallScreen,
  );
  await tester.pumpWidget(env.widget);
  await tester.tap(find.text('Abrir'));
  // Não usa pumpAndSettle: enquanto espera a tag há uma barra de progresso animada.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder primary(String label) => find.widgetWithText(FilledButton, label);
Finder secondary(String label) => find.widgetWithText(OutlinedButton, label);

void main() {
  testWidgets('lê a tag, mostra o código e devolve o UID ao confirmar', (tester) async {
    final nfc = FakeNfcService(script: ['04A32F1B']);
    final result = CaptureResult();
    await open(tester, nfc, result);

    expect(find.text('Tag lida com sucesso.'), findsOneWidget);
    expect(find.text('04A32F1B'), findsOneWidget);
    expect(result.called, isFalse); // ainda aguardando a confirmação

    await tester.tap(primary('Usar esta tag'));
    await tester.pumpAndSettle();

    expect(result.value, '04A32F1B');
    expect(find.text('Tag lida com sucesso.'), findsNothing);
  });

  testWidgets('enquanto espera, mostra a instrução e permite cancelar', (tester) async {
    final nfc = FakeNfcService(); // fica esperando a tag
    final result = CaptureResult();
    await open(tester, nfc, result);

    expect(find.textContaining('Aproxime a tag NFC'), findsOneWidget);
    expect(nfc.reads, 1);

    await tester.tap(secondary('Cancelar'));
    await tester.pumpAndSettle();

    expect(result.called, isTrue);
    expect(result.value, isNull);
    expect(nfc.cancels, greaterThan(0)); // a leitura foi interrompida
  });

  testWidgets('usa o título informado', (tester) async {
    final nfc = FakeNfcService();
    await open(tester, nfc, CaptureResult(), title: 'Substituir tag NFC');
    expect(find.text('Substituir tag NFC'), findsOneWidget);
  });

  testWidgets('falha na leitura mostra a mensagem e permite tentar de novo', (tester) async {
    final nfc = FakeNfcService(script: [
      const NfcReadException('Tempo esgotado. Aproxime a tag e tente de novo.'),
      '0402ABCD',
    ]);
    final result = CaptureResult();
    await open(tester, nfc, result);

    expect(find.text('Tempo esgotado. Aproxime a tag e tente de novo.'), findsOneWidget);

    await tester.tap(primary('Tentar de novo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tag lida com sucesso.'), findsOneWidget);
    expect(find.text('0402ABCD'), findsOneWidget);
    expect(nfc.reads, 2);
  });

  testWidgets('NFC desligado ou ausente: mensagem clara e nova verificação', (tester) async {
    final nfc = FakeNfcService(
      status: NfcHardwareStatus.disabledOrUnavailable,
      script: ['04A32F1B'],
    );
    final result = CaptureResult();
    await open(tester, nfc, result);

    expect(find.textContaining('O NFC não está disponível'), findsOneWidget);
    expect(find.textContaining('ou ele está desligado'), findsOneWidget);
    expect(nfc.reads, 0);

    // O usuário liga o NFC e tenta de novo.
    nfc.status = NfcHardwareStatus.available;
    await tester.tap(primary('Tentar de novo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tag lida com sucesso.'), findsOneWidget);
    expect(nfc.availabilityChecks, 2);
  });

  testWidgets('plataforma sem NFC tem mensagem própria', (tester) async {
    final nfc = FakeNfcService(status: NfcHardwareStatus.unsupportedPlatform);
    await open(tester, nfc, CaptureResult());
    expect(find.text('Este aparelho não permite ler tags NFC.'), findsOneWidget);
  });

  testWidgets('UID fora do padrão do sistema é recusado', (tester) async {
    final nfc = FakeNfcService(script: ['04A3']); // curto demais
    await open(tester, nfc, CaptureResult());

    expect(find.textContaining('fora do padrão'), findsOneWidget);
    expect(find.text('Tag lida com sucesso.'), findsNothing);
  });

  testWidgets('"Ler outra tag" volta a ler', (tester) async {
    final nfc = FakeNfcService(script: ['04A32F1B', '04B1C2D3']);
    await open(tester, nfc, CaptureResult());
    expect(find.text('04A32F1B'), findsOneWidget);

    await tester.tap(secondary('Ler outra tag'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('04B1C2D3'), findsOneWidget);
    expect(find.text('04A32F1B'), findsNothing);
  });

  group('digitar o código manualmente', () {
    Future<void> goManual(WidgetTester tester) async {
      await tester.tap(find.text('Digitar o código manualmente'));
      await tester.pump();
    }

    testWidgets('normaliza o código digitado e devolve o UID', (tester) async {
      final nfc = FakeNfcService();
      final result = CaptureResult();
      await open(tester, nfc, result);
      await goManual(tester);

      await tester.enterText(find.byType(TextField), '04:a3:2f:1b');
      await tester.tap(primary('Usar este código'));
      await tester.pump();

      expect(find.text('04A32F1B'), findsOneWidget);
      await tester.tap(primary('Usar esta tag'));
      await tester.pumpAndSettle();
      expect(result.value, '04A32F1B');
    });

    testWidgets('código inválido mostra mensagem e não avança', (tester) async {
      final nfc = FakeNfcService();
      final result = CaptureResult();
      await open(tester, nfc, result);
      await goManual(tester);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.tap(primary('Usar este código'));
      await tester.pump();

      expect(find.textContaining('Código inválido'), findsOneWidget);
      expect(find.text('Tag lida com sucesso.'), findsNothing);
      expect(result.called, isFalse);
    });

    testWidgets('trocar para digitação cancela a leitura e ignora um resultado atrasado',
        (tester) async {
      final slowRead = Completer<String>();
      final nfc = FakeNfcService(script: [slowRead]);
      await open(tester, nfc, CaptureResult());
      await goManual(tester);
      expect(nfc.cancels, greaterThan(0));

      slowRead.complete('04A32F1B'); // chega depois de o usuário ir para a digitação
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Usar este código'), findsOneWidget); // continua na digitação
      expect(find.text('Tag lida com sucesso.'), findsNothing);
    });

    testWidgets('"Ler pelo NFC" volta à leitura', (tester) async {
      final nfc = FakeNfcService(script: [const NfcReadException('x'), '04A32F1B']);
      await open(tester, nfc, CaptureResult());
      await goManual(tester);

      await tester.tap(secondary('Ler pelo NFC'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('04A32F1B'), findsOneWidget);
    });
  });

  testWidgets('fechar o diálogo interrompe a leitura em andamento', (tester) async {
    final nfc = FakeNfcService();
    await open(tester, nfc, CaptureResult());
    final before = nfc.cancels;

    await tester.tap(secondary('Cancelar'));
    await tester.pumpAndSettle();

    expect(nfc.cancels, greaterThan(before));
  });
}
