import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/session/session_scope.dart';
import '../../data/authorization.dart';

class AuthorizationsPage extends StatefulWidget {
  const AuthorizationsPage({super.key});
  @override
  State<AuthorizationsPage> createState() => _AuthorizationsPageState();
}

class _AuthorizationsPageState extends State<AuthorizationsPage> {
  List<Authorization> items = [];
  bool loading = true, requested = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await SessionScope.of(context).loadAuthorizations();
      final d = r['data'];
      if (d is! List)
        throw const ApiException('Resposta de autorizacoes invalida.');
      final next =
          d
              .whereType<Map<String, dynamic>>()
              .map(Authorization.fromJson)
              .toList()
            ..sort((a, b) => a.status.index.compareTo(b.status.index));
      if (mounted)
        setState(() {
          items = next;
        });
    } on ApiException catch (e) {
      if (mounted)
        setState(() {
          error = e.message;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'Nao foi possivel carregar autorizacoes.';
        });
    } finally {
      if (mounted)
        setState(() {
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minhas autorizacoes')),
    body: RefreshIndicator(
      onRefresh: load,
      child: loading && items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 160),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : error != null && items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!, textAlign: TextAlign.center),
                ),
                Center(
                  child: TextButton(
                    onPressed: load,
                    child: const Text('TENTAR NOVAMENTE'),
                  ),
                ),
              ],
            )
          : items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 100),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Voce ainda nao tem autorizacoes.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                return ListTile(
                  title: Text(a.place),
                  subtitle: Text(a.period + ' | ' + a.timeWindow),
                  trailing: Text(a.usesLabel),
                );
              },
            ),
    ),
  );
}
