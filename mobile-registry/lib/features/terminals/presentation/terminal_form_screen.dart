import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/status_message.dart';
import '../data/terminals_repository.dart';

class TerminalFormScreen extends StatefulWidget {
  const TerminalFormScreen({
    super.key,
    required this.repository,
    this.terminalId,
  });

  final TerminalsRepository repository;
  final String? terminalId;

  @override
  State<TerminalFormScreen> createState() => _TerminalFormScreenState();
}

class _TerminalFormScreenState extends State<TerminalFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  late Future<List<TerminalLocation>> _locations = _load();
  String? _locationId;
  ApiException? _error;
  bool _saving = false;

  Future<List<TerminalLocation>> _load() async {
    final id = widget.terminalId;
    if (id == null) return widget.repository.listLocations();
    final terminal = await widget.repository.get(id);
    final locations = await widget.repository.listLocations();
    if (!mounted) return locations;
    _name.text = terminal.name;
    _latitude.text = terminal.latitude.toString();
    _longitude.text = terminal.longitude.toString();
    _locationId = terminal.locationId;
    return locations;
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  double? _parseCoordinate(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateCoordinate(String? text, int limit) {
    final value = _parseCoordinate(text ?? '');
    if (value == null || !value.isFinite || value.abs() > limit) {
      return 'Informe um número entre -$limit e $limit.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final fields = <String, Object>{
      'name': _name.text.trim(),
      'locationId': _locationId!,
      'latitude': _parseCoordinate(_latitude.text)!,
      'longitude': _parseCoordinate(_longitude.text)!,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.terminalId;
      String? code;
      if (id == null) {
        code = await widget.repository.create(fields);
      } else {
        await widget.repository.update(id, fields);
      }
      if (mounted) Navigator.of(context).pop((code: code));
    } catch (error) {
      if (mounted) setState(() => _error = ApiException.from(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.terminalId == null ? 'Novo terminal' : 'Editar terminal',
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<TerminalLocation>>(
            future: _locations,
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
                      onPressed: () => setState(() => _locations = _load()),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }
              final locations = snapshot.data!;
              if (locations.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: StatusMessage(
                    kind: StatusKind.info,
                    message: 'Cadastre um local no painel web para vincular o terminal.',
                  ),
                );
              }
              final locationId =
                  locations.any((location) => location.id == _locationId)
                  ? _locationId
                  : null;
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (text) {
                        final name = text?.trim() ?? '';
                        return name.isEmpty || name.length > 120
                            ? 'Informe um nome de até 120 caracteres.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: locationId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Local'),
                      items: locations
                          .map(
                            (location) => DropdownMenuItem(
                              value: location.id,
                              child: Text(
                                location.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => _locationId = value,
                      validator: (value) =>
                          value == null ? 'Selecione um local.' : null,
                    ),
                    const SizedBox(height: 12),
                    _coordinateField('Latitude', _latitude, 90),
                    const SizedBox(height: 12),
                    _coordinateField('Longitude', _longitude, 180),
                    if (_error case final error?) ...[
                      const SizedBox(height: 16),
                      StatusMessage(
                        kind: StatusKind.error,
                        message: error.message,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Salvando…' : 'Salvar terminal'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _coordinateField(
    String label,
    TextEditingController controller,
    int limit,
  ) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
      validator: (value) => _validateCoordinate(value, limit),
    );
  }
}
