import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chart_range.dart';
import '../models/order_info.dart';
import '../models/portfolio_history.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'activity_screen.dart';
import 'stock_detail_screen.dart';
import 'tax_report_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  Future<void> _cancel(BuildContext context, OrderInfo o) async {
    final provider = context.read<PortfolioProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Cancelar orden',
      message: '¿Cancelar la ${o.isBuy ? "compra" : "venta"} de ${o.symbol} (${o.typeLabel}${o.classLabel})?',
      confirmLabel: 'Cancelar orden',
      destructive: true,
    );
    if (!ok) return;
    try {
      await provider.cancelOrder(o.id);
      if (context.mounted) showSnack(context, 'Orden cancelada');
    } catch (e) {
      if (context.mounted) showSnack(context, 'No se pudo cancelar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final account = provider.account;

    if (!provider.isConfigured) {
      return const NotConnectedScaffold(
        title: 'Portafolio',
        icon: Icons.pie_chart_rounded,
        message: 'Ve a Ajustes para ver tu saldo y tus posiciones.',
      );
    }

    final open = provider.openOrders;
    final closed = provider.orders.where((o) => !o.isOpen).take(15).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portafolio'),
        actions: [
          IconButton(
            tooltip: provider.hideBalances ? 'Mostrar saldos' : 'Ocultar saldos',
            icon: Icon(provider.hideBalances ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: provider.toggleHideBalances,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final page = v == 'activity' ? const ActivityScreen() : const TaxReportScreen();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'activity', child: Text('Historial de movimientos')),
              PopupMenuItem(value: 'tax', child: Text('Reporte para el SII')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (provider.isLive)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LiveModeBanner(),
              ),
            if (account != null) ...[
              Card(
                color: scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LabelWithTip('Todo tu dinero', 'saldo_total'),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          provider.main(account.portfolioValue),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (provider.secondary(account.portfolioValue) != null)
                        Text(provider.secondary(account.portfolioValue)!,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 16),
                      StatGrid(
                        items: [
                          ('Disponible', provider.main(account.cash)),
                          ('Poder de compra', provider.main(account.buyingPower)),
                          ('Pagaste por tus acciones', provider.main(provider.totalCostBasis)),
                          ('Tus acciones valen hoy', provider.main(provider.totalMarketValue)),
                        ],
                        tips: const {
                          'Disponible': 'efectivo',
                          'Poder de compra': 'poder_compra',
                          'Pagaste por tus acciones': 'invertido',
                          'Tus acciones valen hoy': 'saldo_total',
                        },
                      ),
                      if (provider.usdClp != null && provider.settings.showClp) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Dólar observado: ${Fmt.clp(provider.usdClp!)}',
                                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                            const InfoTip('dolar', size: 14),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GainLossCard(
                period: 'Hoy',
                usd: account.dayChange,
                percent: account.dayChangePercent,
                term: 'ganancia_hoy',
              ),
              if (provider.positions.isNotEmpty) ...[
                const SizedBox(height: 12),
                GainLossCard(
                  period: 'Desde que compraste',
                  usd: provider.totalUnrealizedPl,
                  percent: provider.totalCostBasis == 0
                      ? null
                      : provider.totalUnrealizedPl / provider.totalCostBasis * 100,
                  term: 'ganancia_total',
                ),
              ],
              const SizedBox(height: 16),
              const _HistoryCard(),
              const SizedBox(height: 24),
            ],
            if (provider.positions.length > 1) ...[
              const SectionTitle('Cómo está repartido tu dinero', trailing: InfoTip('diversificar')),
              const _AllocationCard(),
              const SizedBox(height: 24),
            ],
            const SectionTitle('Tus acciones', trailing: InfoTip('ganancia_total')),
            if (provider.positions.isEmpty)
              Text('Aún no tienes acciones. Búscalas en la pestaña Mercado.',
                  style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ...provider.positions.map((p) {
                final color = p.unrealizedPl >= 0 ? AppTheme.up : AppTheme.down;
                final name = provider.assetInfo(p.symbol)?.name;
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: p.symbol)),
                      ),
                      title: Text(
                        name == null || name.isEmpty ? p.symbol : '${Fmt.shortName(name)} · ${p.symbol}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${Fmt.qty(p.qty)} acc. a ${Fmt.usd(p.currentPrice)} c/u\n'
                        'Hoy ${provider.mainSigned(p.unrealizedIntradayPl)} (${Fmt.pct(p.changeTodayPercent)})',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(provider.main(p.marketValue), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            provider.mainSigned(p.unrealizedPl),
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          Text(Fmt.pct(p.unrealizedPlPercent),
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionTitle('Órdenes pendientes', trailing: InfoTip('orden')),
              ...open.map((o) => _OrderTile(order: o, onCancel: () => _cancel(context, o))),
            ],
            const SizedBox(height: 24),
            SectionTitle(
              'Órdenes recientes',
              trailing: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ActivityScreen())),
                child: const Text('Ver historial'),
              ),
            ),
            if (closed.isEmpty)
              Text('Sin órdenes todavía.', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ...closed.map((o) => _OrderTile(order: o)),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderInfo order;
  final VoidCallback? onCancel;
  const _OrderTile({required this.order, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = switch (o.status) {
      'filled' => AppTheme.up,
      'rejected' || 'canceled' || 'expired' => AppTheme.down,
      _ => scheme.onSurfaceVariant,
    };
    final amount = o.qty != null ? Fmt.qty(o.qty!) : (o.notional != null ? Fmt.usd(o.notional!) : '-');
    final extra = [
      o.typeLabel + o.classLabel,
      if (o.limitPrice != null) 'lím. ${Fmt.usd(o.limitPrice!)}',
      if (o.stopPrice != null) 'stop ${Fmt.usd(o.stopPrice!)}',
      if (o.trailPercent != null) 'trail ${Fmt.number(o.trailPercent!)}%',
      DateFormat('d MMM HH:mm', 'es').format(o.createdAt.toLocal()),
    ].join(' · ');
    return Card(
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          '${o.isBuy ? "Compra" : "Venta"} ${o.symbol} · $amount',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${o.statusLabel}\n$extra',
          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        isThreeLine: true,
        trailing: onCancel != null
            ? TextButton(onPressed: onCancel, child: const Text('Cancelar'))
            : (o.filledAvgPrice != null ? Text(Fmt.usd(o.filledAvgPrice!)) : null),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard();

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  HistoryRange _range = HistoryRange.month1;
  final Map<HistoryRange, PortfolioHistory> _cache = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(_range);
  }

  Future<void> _load(HistoryRange r) async {
    setState(() {
      _range = r;
      _error = null;
    });
    if (_cache.containsKey(r)) return;
    setState(() => _loading = true);
    try {
      _cache[r] = await context.read<PortfolioProvider>().requireService().getPortfolioHistory(r);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final h = _cache[_range];
    final points = h?.points ?? const [];
    final isUp = (h?.change ?? 0) >= 0;
    final color = isUp ? AppTheme.up : AppTheme.down;
    final fmt = _range == HistoryRange.day1
        ? DateFormat('HH:mm')
        : (_range == HistoryRange.week1 ? DateFormat('EEE d HH:mm', 'es') : DateFormat('d MMM yy', 'es'));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                h == null || points.length < 2
                    ? 'Evolución del portafolio'
                    : 'En ${_range.label}: ${provider.moneySigned(h.change)} (${Fmt.pct(h.changePercent)})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: h == null || points.length < 2 ? scheme.onSurface : color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)))
                      : points.length < 2
                          ? Center(
                              child: Text('Todavía no hay historial para este rango',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)))
                          : LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipItems: (spots) => spots.map((s) {
                                      final p = points[s.x.toInt()];
                                      return LineTooltipItem(
                                        '${fmt.format(p.time)}\n${provider.money(p.equity)}',
                                        const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: List.generate(
                                        points.length, (i) => FlSpot(i.toDouble(), points[i].equity)),
                                    color: color,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
                                  ),
                                ],
                              ),
                            ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: HistoryRange.values
                  .map((r) => ChoiceChip(
                        label: Text(r.label, style: const TextStyle(fontSize: 12)),
                        selected: r == _range,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _load(r),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationCard extends StatefulWidget {
  const _AllocationCard();

  @override
  State<_AllocationCard> createState() => _AllocationCardState();
}

class _AllocationCardState extends State<_AllocationCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final positions = [...provider.positions]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final cash = provider.account?.cash ?? 0;
    final total = positions.fold<double>(0, (a, p) => a + p.marketValue) + (cash > 0 ? cash : 0);
    if (total <= 0) return const SizedBox.shrink();

    // Máximo 7 porciones + "Otras" + efectivo, para que se lea bien.
    final slices = <(String, double)>[];
    for (var i = 0; i < positions.length; i++) {
      if (i < 7) {
        slices.add((positions[i].symbol, positions[i].marketValue));
      } else if (i == 7) {
        slices.add(('Otras', positions.skip(7).fold(0.0, (a, p) => a + p.marketValue)));
      }
    }
    if (cash > 0) slices.add(('Efectivo', cash));

    Color colorFor(int i, String label) =>
        label == 'Efectivo' ? scheme.outline : AppTheme.chartPalette[i % AppTheme.chartPalette.length];

    final top = positions.isEmpty ? 0.0 : positions.first.marketValue / total * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 36,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, resp) => setState(
                            () => _touched = resp?.touchedSection?.touchedSectionIndex),
                      ),
                      sections: List.generate(slices.length, (i) {
                        final s = slices[i];
                        return PieChartSectionData(
                          value: s.$2,
                          color: colorFor(i, s.$1),
                          radius: _touched == i ? 34 : 28,
                          showTitle: false,
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(slices.length, (i) {
                      final s = slices[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: colorFor(i, s.$1), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(s.$1,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _touched == i ? FontWeight.w800 : FontWeight.w500)),
                            ),
                            Text(Fmt.pct(s.$2 / total * 100, signed: false),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            if (top > 40) ...[
              const SizedBox(height: 12),
              InfoBanner(
                '${positions.first.symbol} es el ${Fmt.pct(top, signed: false)} de tu portafolio. '
                'Una concentración alta aumenta el riesgo si esa acción cae.',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
