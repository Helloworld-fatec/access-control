import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_message.dart';
import '../data/terminals_repository.dart';
import 'terminal_form_screen.dart';

enum _TerminalAction { edit, rotate, delete }

class TerminalsScreen extends StatefulWidget {
  const TerminalsScreen({super.key, required this.repository});

  final TerminalsRepository repository;

  @override
  State<TerminalsScreen> createState() => _TerminalsScreenState();
}

class _TerminalsScreenState extends State<TerminalsScreen> {
  var _page = 1;
  String? _locationId;
  late Future<TerminalPage> _terminals = _loadPage();
  late Future<List<TerminalLocation>> _locations = widget.repository
      .listLocations();
  bool _busy = false;
  String? _actionError;

  Future<TerminalPage> _loadPage() async {
    final page = _page;
    final locationId = _locationId;
    final result = await widget.repository.list(
      page: page,
      locationId: locationId,
    );
    if (page <= result.totalPages ||
        !mounted ||
        page != _page ||
        locationId != _locationId) {
      return result;
    }
    _page = result.totalPages;
    return widget.repository.list(page: _page, locationId: locationId);
  }

  void _changePage(int page) => setState(() {
    _page = page;
    _terminals = _loadPage();
  });

  Future<void> _openForm([String? id]) async {
    final result = await Navigator.of(context).push<({String? code})>(
      MaterialPageRoute(
        builder: (_) =>
            TerminalFormScreen(repository: widget.repository, terminalId: id),
      ),
    );
    if (!mounted || result == null) return;
    _changePage(_page);
    if (result.code case final code?) await _showCode(code);
  }

  Future<void> _showCode(String code) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Código do terminal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            code,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Cole este código em Configurações → Código do terminal no Mobile Readings. Ele é exibido uma vez.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Código copiado.')));
            }
          },
          child: const Text('Copiar código'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Concluir'),
        ),
      ],
    ),
  );

  Future<void> _handleAction(_TerminalAction action, Terminal terminal) async {
    if (_busy) return;
    if (action == _TerminalAction.edit) {
      await _openForm(terminal.id);
      return;
    }
    final deleting = action == _TerminalAction.delete;
    final confirmed = await showConfirmDialog(
      context,
      title: deleting ? 'Excluir terminal' : 'Reemitir código',
      message: deleting
          ? 'Excluir o terminal “${terminal.name}”?'
          : 'O código atual de “${terminal.name}” deixará de funcionar. Configure o novo código no Mobile Readings.',
      confirmLabel: deleting ? 'Excluir' : 'Reemitir',
      destructive: deleting,
    );
    if (!mounted || !confirmed) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      if (deleting) {
        await widget.repository.delete(terminal.id);
        if (mounted) _changePage(_page);
      } else {
        final code = await widget.repository.rotateCode(terminal.id);
        if (mounted) await _showCode(code);
      }
    } catch (error) {
      final apiError = ApiException.from(error);
      if (mounted) {
        setState(
          () => _actionError = apiError.code == 'TERMINAL_IN_USE'
              ? 'Este terminal possui histórico de acessos e não pode ser excluído.'
              : apiError.message,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Terminais')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _locationFilter(),
              ),
              if (_actionError case final error?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StatusMessage(kind: StatusKind.error, message: error),
                ),
              Expanded(
                child: FutureBuilder<TerminalPage>(
                  future: _terminals,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          StatusMessage(
                            kind: StatusKind.error,
                            message: userMessageFor(snapshot.error!),
                          ),
                          TextButton(
                            onPressed: () => _changePage(_page),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      );
                    }
                    final page = snapshot.data!;
                    if (page.items.isEmpty && page.totalPages == 1) {
                      return const Center(
                        child: Text('Nenhum terminal encontrado.'),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              page.totalPages > 1 ? 0 : 88,
                            ),
                            itemCount: page.items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                _terminalTile(page.items[index]),
                          ),
                        ),
                        if (page.totalPages > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 76),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Página anterior',
                                  onPressed: _busy || _page <= 1
                                      ? null
                                      : () => _changePage(_page - 1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('Página $_page de ${page.totalPages}'),
                                IconButton(
                                  tooltip: 'Próxima página',
                                  onPressed: _busy || _page >= page.totalPages
                                      ? null
                                      : () => _changePage(_page + 1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onDark,
          onPressed: _busy ? null : _openForm,
          icon: const Icon(Icons.add),
          label: const Text('Novo terminal'),
        ),
      ),
    );
  }

  Widget _locationFilter() => FutureBuilder<List<TerminalLocation>>(
    future: _locations,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () =>
              setState(() => _locations = widget.repository.listLocations()),
          child: const Text('Tentar carregar locais novamente'),
        );
      }
      return DropdownButton<String>(
        isExpanded: true,
        value: _locationId ?? '',
        items: [
          const DropdownMenuItem(value: '', child: Text('Todos os locais')),
          for (final location in snapshot.data!)
            DropdownMenuItem(
              value: location.id,
              child: Text(location.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _busy
            ? null
            : (value) {
                _locationId = value == '' ? null : value;
                _changePage(1);
              },
      );
    },
  );

  Widget _terminalTile(Terminal terminal) => ListTile(
    title: Text(terminal.name),
    subtitle: Text(terminal.location?.label ?? 'Local indisponível'),
    onTap: _busy ? null : () => _openForm(terminal.id),
    trailing: PopupMenuButton<_TerminalAction>(
      enabled: !_busy,
      tooltip: 'Ações de ${terminal.name}',
      onSelected: (action) => _handleAction(action, terminal),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _TerminalAction.edit, child: Text('Editar')),
        PopupMenuItem(
          value: _TerminalAction.rotate,
          child: Text('Reemitir código'),
        ),
        PopupMenuItem(value: _TerminalAction.delete, child: Text('Excluir')),
      ],
    ),
  );
}
