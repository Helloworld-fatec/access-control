import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/test_app.dart';
import '../../helpers/users_fixtures.dart';

void main() {
  testWidgets('admin gerencia terminais pela tela inicial', (tester) async {
    const location = {'id': 'l1', 'building': 'Bloco A'};
    var terminal = <String, Object?>{
      'id': 't1',
      'name': 'Entrada',
      'locationId': 'l1',
      'location': location,
      'latitude': 0,
      'longitude': 0,
    };
    var inUse = true;
    final adapter = FakeAdapter([
      (request) {
        final response = switch ((request.method, request.uri.path)) {
          ('GET', '/api/users') => FakeAdapter.json(200, pageJson([])),
          ('GET', '/api/locations') => FakeAdapter.json(
            200,
            pageJson([location]),
          ),
          ('GET', '/api/terminals') => FakeAdapter.json(
            200,
            pageJson(terminal.isEmpty ? [] : [terminal]),
          ),
          ('GET', '/api/terminals/t1') => FakeAdapter.json(200, terminal),
          ('POST', '/api/terminals') => FakeAdapter.json(201, {
            'apiKey': '01abef',
          }),
          ('PUT', '/api/terminals/t1') => FakeAdapter.json(
            200,
            terminal = {...terminal, ...request.data as Map<String, Object?>},
          ),
          ('POST', '/api/terminals/t1/rotate-key') => FakeAdapter.json(200, {
            'apiKey': 'abc123',
          }),
          ('DELETE', '/api/terminals/t1') when inUse => FakeAdapter.json(409, {
            'error': {'code': 'TERMINAL_IN_USE'},
          }),
          ('DELETE', '/api/terminals/t1') => FakeAdapter.json(
            204,
            terminal = {},
          ),
          _ => throw StateError(
            'Requisição inesperada: ${request.method} ${request.uri}',
          ),
        };
        expect(request.headers['Authorization'], 'Bearer tok-123');
        return response(request);
      },
    ]);
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final env = await buildTestEnv(
      tester,
      adapter: adapter,
      signedInAs: testAdmin,
    );
    await tester.pumpWidget(env.widget);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Terminais'));
    expect(find.text('Entrada'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Bloco A').last);
    expect(adapter.requests.last.queryParameters['locationId'], 'l1');

    await tapVisible(tester, find.text('Novo terminal'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Portaria');
    await tester.enterText(fields.at(1), '91');
    await tester.enterText(fields.at(2), '46,25');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Bloco A').last);
    await tapVisible(tester, find.text('Salvar terminal'));
    expect(find.text('Informe um número entre -90 e 90.'), findsOneWidget);
    await tester.enterText(fields.at(1), '-23,5');
    await tapVisible(tester, find.text('Salvar terminal'));
    expect(find.text('01abef'), findsOneWidget);
    final create = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(create.data, {
      'name': 'Portaria',
      'locationId': 'l1',
      'latitude': -23.5,
      'longitude': 46.25,
    });
    await tapVisible(tester, find.text('Copiar código'));
    expect(copied, '01abef');
    await tapVisible(tester, find.text('Concluir'));

    await tapVisible(tester, find.text('Entrada'));
    expect(find.text('Editar terminal'), findsOneWidget);
    await tester.enterText(fields.first, 'Entrada principal');
    await tapVisible(tester, find.text('Salvar terminal'));
    expect(find.text('Entrada principal'), findsOneWidget);

    final menu = find.byTooltip('Ações de Entrada principal');
    await tapVisible(tester, menu);
    await tapVisible(tester, find.text('Reemitir código'));
    await tapVisible(tester, find.text('Reemitir'));
    expect(find.text('abc123'), findsOneWidget);
    await tapVisible(tester, find.text('Concluir'));

    Future<void> deleteTerminal() async {
      await tapVisible(tester, menu);
      await tapVisible(tester, find.text('Excluir'));
      await tapVisible(tester, find.text('Excluir'));
    }

    await deleteTerminal();
    expect(find.textContaining('possui histórico'), findsOneWidget);
    expect(find.text('Entrada principal'), findsOneWidget);
    inUse = false;
    await deleteTerminal();
    expect(find.text('Nenhum terminal encontrado.'), findsOneWidget);
  });
}
