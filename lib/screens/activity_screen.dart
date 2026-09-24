import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/account_activity.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

enum _Filter { all, trades, dividends, cash }

/// Historial completo de la cuenta: compras, ventas, dividendos,
/// retenciones, depósitos y comisiones.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<AccountActivity> _items = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await context.read<PortfolioProvider>().requireService().getActivities(maxPages: 10);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _matches(AccountActivity a) => switch (_filter) {
        _Filter.all => true,
        _Filter.trades => a.isFill,
        _Filter.dividends => a.isDividend || a.isWithholding,
        _Filter.cash => !a.isFill && !a.isDividend && !a.isWithholding,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final visible = _items.where(_matches).toList();
    final year = DateTime.now().year;
    final divYear = _items
        .where((a) => a.isDividend && a.date.year == year)
        .fold<double>(0, (s, a) => s + (a.netAmount ?? 0));
    final withheldYear = _items
        .where((a) => a.isWithholding && a.date.year == year)
        .fold<double>(0, (s, a) => s + (a.netAmount ?? 0).abs());
    final monthFmt = DateFormat("MMMM 'de' yyyy", 'es');
    final dayFmt = DateFormat('d MMM, HH:mm', 'es');

    final children = <Widget>[];
    String? lastMonth;
    for (final a in visible) {
      final m = monthFmt.format(a.date);
      if (m != lastMonth) {
        lastMonth = m;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Text(m[0].toUpperCase() + m.substring(1),
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
        ));
      }
      final flow = a.cashFlow;
      children.add(Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            switch (a.type) {
              'FILL' => a.side == 'buy' ? Icons.add_shopping_cart_rounded : Icons.sell_rounded,
              'DIVNRA' => Icons.account_balance_rounded,
              _ when a.isDividend => Icons.payments_rounded,
              'CSD' => Icons.south_west_rounded,
              'CSW' => Icons.north_east_rounded,
              _ => Icons.receipt_long_rounded,
            },
            color: flow >= 0 ? AppTheme.up : scheme.onSurfaceVariant,
          ),
          title: Text(
            '${a.typeLabel}${a.symbol != null ? " ${a.symbol}" : ""}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            [
              dayFmt.format(a.date),
              if (a.isFill && a.qty != null && a.price != null)
                '${Fmt.qty(a.qty!)} × ${Fmt.usd(a.price!)}',
              if (!a.isFill && a.description != null && a.description!.isNotEmpty) a.description!,
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            provider.moneySigned(flow),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: flow >= 0 ? AppTheme.up : scheme.onSurface,
            ),
          ),
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'No se pudo cargar',
                    message: _error!,
                    actionLabel: 'Reintentar',
                    onAction: _load,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: StatGrid(items: [
                            ('Dividendos $year', provider.money(divYear)),
                            ('Retenido EE.UU. $year', provider.money(withheldYear)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in _Filter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(switch (f) {
                                    _Filter.all => 'Todo',
                                    _Filter.trades => 'Compras y ventas',
                                    _Filter.dividends => 'Dividendos',
                                    _Filter.cash => 'Depósitos y otros',
                                  }),
                                  selected: _filter == f,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => _filter = f),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (visible.isEmpty)
                        const EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Sin movimientos',
                          message: 'Aquí aparecerán tus compras, ventas y dividendos.',
                        )
                      else
                        ...children,
                    ],
                  ),
                ),
    );
  }
}
