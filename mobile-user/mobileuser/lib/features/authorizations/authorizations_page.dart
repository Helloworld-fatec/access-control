import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/authorization.dart';
import '../../data/mock_authorizations.dart';

class AuthorizationsPage extends StatefulWidget {
  const AuthorizationsPage({super.key});

  @override
  State<AuthorizationsPage> createState() => _AuthorizationsPageState();
}

class _AuthorizationsPageState extends State<AuthorizationsPage> {
  late List<Authorization> _items = _sorted(mockAuthorizations);

  // Ativas primeiro.
  List<Authorization> _sorted(List<Authorization> list) {
    final copy = [...list];
    copy.sort((a, b) => a.status.index.compareTo(b.status.index));
    return copy;
  }

  Future<void> _refresh() async {
    // MOCK: depois, GET /me/authorizations.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _items = _sorted(mockAuthorizations));
  }

  void _showDetail(Authorization a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.place, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatusChip(status: a.status),
            const SizedBox(height: 20),
            _DetailRow(icon: Icons.date_range, label: 'Período', value: a.period),
            _DetailRow(
                icon: Icons.schedule, label: 'Horário', value: a.timeWindow),
            _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'Usos restantes',
                value: a.usesLabel),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FECHAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas autorizações')),
      body: RefreshIndicator(
        color: AppColors.black,
        backgroundColor: AppColors.yellow,
        onRefresh: _refresh,
        child: _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.inbox_outlined,
                      size: 80, color: AppColors.yellow),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Você ainda não tem autorizações. Procure a administração.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) => _AuthorizationCard(
                  item: _items[i],
                  onTap: () => _showDetail(_items[i]),
                ),
              ),
      ),
    );
  }
}

class _AuthorizationCard extends StatelessWidget {
  const _AuthorizationCard({required this.item, required this.onTap});

  final Authorization item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = item.status == AuthorizationStatus.active;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left: BorderSide(
                color: active ? AppColors.yellow : AppColors.surfaceHigh,
                width: 8,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.place,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(item.period,
                        style: const TextStyle(color: AppColors.grey)),
                    Text(item.timeWindow,
                        style: const TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 10),
                    _StatusChip(status: item.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Situação com ícone + texto (não depende só de cor).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AuthorizationStatus status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final IconData icon;
    late final Color bg;
    late final Color fg;

    switch (status) {
      case AuthorizationStatus.active:
        text = 'Ativa';
        icon = Icons.check_circle;
        bg = AppColors.yellow;
        fg = AppColors.black;
      case AuthorizationStatus.expired:
        text = 'Expirada';
        icon = Icons.history;
        bg = AppColors.surfaceHigh;
        fg = AppColors.white;
      case AuthorizationStatus.cancelled:
        text = 'Cancelada';
        icon = Icons.block;
        bg = AppColors.danger;
        fg = AppColors.black;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.yellow, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
