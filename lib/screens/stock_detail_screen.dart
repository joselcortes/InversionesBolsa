import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/chart_range.dart';
import '../models/news_item.dart';
import '../models/order_info.dart';
import '../models/price_bar.dart';
import '../providers/portfolio_provider.dart';
import '../services/alpaca_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/indicators.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'alerts_screen.dart';
import 'order_sheet.dart';
import 'protect_position_sheet.dart';

enum ChartStyle { line, area, candlestick, bar }

const _sma20Color = Color(0xFFF59E0B);
const _sma50Color = Color(0xFFA855F7);

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final Map<ChartRange, List<PriceBar>> _barsCache = {};
  List<PriceBar> _yearBars = [];
  List<NewsItem> _news = [];
  bool _loading = true;
  bool _loadingRange = false;
  String? _error;
  ChartRange _range = ChartRange.month3;
  ChartStyle _chartStyle = ChartStyle.area;
  bool _showSma = true;
  bool _onlyAnalystNews = false;

  List<PriceBar> get _bars => _barsCache[_range] ?? const [];

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
      final service = context.read<PortfolioProvider>().requireService();
      final results = await Future.wait([
        service.getBarsForRange(widget.symbol, ChartRange.year1),
        service.getNews(symbols: [widget.symbol], limit: 20),
      ]);
      _yearBars = results[0] as List<PriceBar>;
      _barsCache
        ..clear()
        ..[ChartRange.year1] = _yearBars;
      _news = (results[1] as List<NewsItem>)
        ..sort((a, b) {
          if (a.isAnalystCoverage != b.isAnalystCoverage) {
            return a.isAnalystCoverage ? -1 : 1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
      await _loadRange(_range, service: service);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRange(ChartRange range, {AlpacaService? service}) async {
    if (_barsCache.containsKey(range)) {
      setState(() => _range = range);
      return;
    }
    if (range == ChartRange.month1 || range == ChartRange.month3) {
      // Se sacan del año que ya está descargado.
      final cutoff = DateTime.now().subtract(range.lookback);
      _barsCache[range] = _yearBars.where((b) => b.time.isAfter(cutoff)).toList();
      setState(() => _range = range);
      return;
    }
    setState(() {
      _range = range;
      _loadingRange = true;
    });
    try {
      final s = service ?? context.read<PortfolioProvider>().requireService();
      _barsCache[range] = await s.getBarsForRange(widget.symbol, range);
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo cargar el gráfico: $e');
    }
    if (mounted) setState(() => _loadingRange = false);
  }

  Future<void> _cancelOrder(OrderInfo o) async {
    final provider = context.read<PortfolioProvider>();
    final ok = await confirmDialog(
      context,
      title: 'Cancelar orden',
      message: '¿Cancelar la ${o.isBuy ? "compra" : "venta"} de ${o.symbol} (${o.typeLabel})?',
      confirmLabel: 'Cancelar orden',
      destructive: true,
    );
    if (!ok) return;
    try {
      await provider.cancelOrder(o.id);
      if (mounted) showSnack(context, 'Orden cancelada');
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo cancelar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final quote = provider.quotes[widget.symbol];
    final position = provider.positionFor(widget.symbol);
    final asset = provider.assetInfo(widget.symbol);
    final inWatchlist = provider.watchlist.contains(widget.symbol);
    final symbolOrders = provider.openOrders.where((o) => o.symbol == widget.symbol).toList();
    final scheme = Theme.of(context).colorScheme;
    final visibleNews =
        _onlyAnalystNews ? _news.where((n) => n.isAnalystCoverage).toList() : _news;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (asset != null)
              Text(asset.name,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Crear alerta',
            icon: const Icon(Icons.notification_add_outlined),
            onPressed: () => showAlertSheet(context, symbol: widget.symbol),
          ),
          IconButton(
            tooltip: inWatchlist ? 'Quitar de mi lista' : 'Agregar a mi lista',
            icon: Icon(inWatchlist ? Icons.star_rounded : Icons.star_border_rounded,
                color: inWatchlist ? Colors.amber : null),
            onPressed: () async {
              if (inWatchlist) {
                await provider.removeFromWatchlist(widget.symbol);
              } else {
                final err = await provider.addToWatchlist(widget.symbol);
                if (err != null && context.mounted) showSnack(context, err);
              }
            },
          ),
        ],
      ),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (quote != null) ...[
                        Text(
                          Fmt.usd(quote.price),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ChangeChip(changePercent: quote.changePercent),
                            const SizedBox(width: 8),
                            Text('${Fmt.usdSigned(quote.change)} hoy',
                                style: TextStyle(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                        if (provider.clp(quote.price) != null) ...[
                          const SizedBox(height: 4),
                          Text('${provider.clp(quote.price)} por acción',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 16),
                      ],
                      _RangeSelector(
                        value: _range,
                        onChanged: (r) => _loadRange(r),
                      ),
                      const SizedBox(height: 8),
                      if (_bars.length > 1 && !_loadingRange)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RangeChangeText(bars: _bars, range: _range),
                        ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(4, 16, 16, 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        height: 300,
                        child: _loadingRange
                            ? const Center(child: CircularProgressIndicator())
                            : _bars.length < 2
                                ? Center(
                                    child: Text('Sin datos para este rango',
                                        style: TextStyle(color: scheme.onSurfaceVariant)))
                                : Column(
                                    children: [
                                      Expanded(
                                        child: _PriceChart(
                                          bars: _bars,
                                          style: _chartStyle,
                                          range: _range,
                                          showSma: _showSma,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(height: 50, child: _VolumeChart(bars: _bars)),
                                    ],
                                  ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ChartTypeSelector(
                              value: _chartStyle,
                              onChanged: (v) => setState(() => _chartStyle = v),
                            ),
                          ),
                        ],
                      ),
                      if (_chartStyle == ChartStyle.candlestick)
                        const HelpLink('velas', text: '¿Cómo leer las velas?'),
                      if (_chartStyle == ChartStyle.line || _chartStyle == ChartStyle.area)
                        Row(
                          children: [
                            const InfoTip('media_movil'),
                            FilterChip(
                              label: const Text('Medias móviles', style: TextStyle(fontSize: 12)),
                              selected: _showSma,
                              onSelected: (v) => setState(() => _showSma = v),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            if (_showSma) ...[
                              const _LegendDot(color: _sma20Color, label: 'MM20'),
                              const SizedBox(width: 8),
                              const _LegendDot(color: _sma50Color, label: 'MM50'),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.up),
                              onPressed: () => showOrderSheet(
                                context,
                                symbol: widget.symbol,
                                side: 'buy',
                                quote: quote,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Comprar', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.down),
                              onPressed: position == null
                                  ? null
                                  : () => showOrderSheet(
                                        context,
                                        symbol: widget.symbol,
                                        side: 'sell',
                                        quote: quote,
                                      ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Vender', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (position != null) ...[
                        const SizedBox(height: 24),
                        SectionTitle(
                          'Tu inversión en ${widget.symbol}',
                          trailing: TextButton.icon(
                            onPressed: () => showProtectPositionSheet(context, position),
                            icon: const Icon(Icons.shield_outlined, size: 18),
                            label: const Text('Proteger'),
                          ),
                        ),
                        GainLossCard(
                          period: 'Con esta acción',
                          usd: position.unrealizedPl,
                          percent: position.unrealizedPlPercent,
                          term: 'ganancia_total',
                          footnote: 'Hoy: ${provider.mainSigned(position.unrealizedIntradayPl)} '
                              '(${Fmt.pct(position.changeTodayPercent)})',
                        ),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: StatGrid(
                              items: [
                                ('Tienes', '${Fmt.qty(position.qty)} ${position.qty == 1 ? "acción" : "acciones"}'),
                                ('Valen hoy', provider.main(position.marketValue)),
                                ('Pagaste', provider.main(position.costBasis)),
                                ('Costo promedio', Fmt.usd(position.avgEntryPrice)),
                                if (position.qtyAvailable < position.qty)
                                  ('En órdenes pendientes', Fmt.qty(position.qty - position.qtyAvailable)),
                              ],
                              tips: const {
                                'Pagaste': 'invertido',
                                'Costo promedio': 'costo_promedio',
                                'En órdenes pendientes': 'orden',
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿Te preocupa que baje? Toca "Proteger" para que se venda sola si cae mucho.',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        const HelpLink('stop_loss', text: '¿Qué es un stop-loss?'),
                      ],
                      if (symbolOrders.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const SectionTitle('Órdenes pendientes', trailing: InfoTip('orden')),
                        ...symbolOrders.map((o) => _OpenOrderTile(order: o, onCancel: () => _cancelOrder(o))),
                      ],
                      const SizedBox(height: 24),
                      const SectionTitle('Datos de la acción'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _StatsGrid(yearBars: _yearBars, provider: provider, symbol: widget.symbol),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Indicadores calculados con datos del feed IEX. Son referenciales, no una recomendación.',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Noticias',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface)),
                          FilterChip(
                            label: const Text('Solo análisis'),
                            selected: _onlyAnalystNews,
                            onSelected: (v) => setState(() => _onlyAnalystNews = v),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Priorizamos coberturas de analistas (ratings, price targets) sobre '
                        'notas de prensa genéricas. Esto no garantiza que acierten.',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      if (visibleNews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Sin noticias que mostrar.',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        )
                      else
                        ...visibleNews.map((n) => _NewsTile(item: n)),
                    ],
                  ),
                ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<PriceBar> yearBars;
  final PortfolioProvider provider;
  final String symbol;
  const _StatsGrid({required this.yearBars, required this.provider, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final q = provider.quotes[symbol];
    final closes = yearBars.map((b) => b.close).toList();
    String usdOr(double? v) => v == null ? '—' : Fmt.usd(v);
    final hi52 = yearBars.isEmpty ? null : yearBars.map((b) => b.high).reduce((a, b) => a > b ? a : b);
    final lo52 = yearBars.isEmpty ? null : yearBars.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    final rsi = Indicators.rsi(closes);
    final vol = Indicators.annualVolatility(closes);
    final avgVol = yearBars.length >= 20
        ? yearBars.sublist(yearBars.length - 20).map((b) => b.volume).reduce((a, b) => a + b) / 20
        : null;
    final sma20 = Indicators.sma(closes, 20);
    final sma50 = Indicators.sma(closes, 50);
    final sma200 = Indicators.sma(closes, 200);

    String vsPrice(double? sma) {
      if (sma == null) return '—';
      if (q == null) return Fmt.usd(sma);
      return '${Fmt.usd(sma)} (${q.price >= sma ? "precio sobre" : "precio bajo"})';
    }

    String fromHigh() {
      if (hi52 == null || q == null) return '';
      return ' · ${Fmt.pct((q.price - hi52) / hi52 * 100)} desde máx';
    }

    return StatGrid(tips: const {
      'Volumen (IEX)': 'volumen',
      'Vol. vs ayer': 'volumen',
      'Compra / Venta': 'bid_ask',
      'Spread': 'bid_ask',
      'Máx. 52 semanas': 'max52',
      'Mín. 52 semanas': 'max52',
      'Media 20 días': 'media_movil',
      'Media 50 días': 'media_movil',
      'Media 200 días': 'media_movil',
      'RSI (14)': 'rsi',
      'Volatilidad anual': 'volatilidad',
      'Vol. promedio 20 d': 'volumen',
    }, items: [
      ('Apertura', usdOr(q?.open)),
      ('Cierre anterior', usdOr(q?.previousClose)),
      ('Máx. del día', usdOr(q?.high)),
      ('Mín. del día', usdOr(q?.low)),
      ('Volumen (IEX)', q?.volume == null ? '—' : Fmt.compact(q!.volume!)),
      ('Vol. vs ayer', q?.volumeRatio == null ? '—' : '${Fmt.number(q!.volumeRatio!)}x'),
      ('Compra / Venta', q?.bid == null || q?.ask == null ? '—' : '${Fmt.usd(q!.bid!)} / ${Fmt.usd(q.ask!)}'),
      ('Spread', q?.spread == null ? '—' : Fmt.usd(q!.spread!)),
      ('Máx. 52 semanas', '${usdOr(hi52)}${fromHigh()}'),
      ('Mín. 52 semanas', usdOr(lo52)),
      ('Media 20 días', vsPrice(sma20)),
      ('Media 50 días', vsPrice(sma50)),
      ('Media 200 días', vsPrice(sma200)),
      ('RSI (14)', rsi == null ? '—' : '${rsi.toStringAsFixed(0)} · ${Indicators.rsiLabel(rsi)}'),
      ('Volatilidad anual', vol == null ? '—' : '${Fmt.number(vol)}%'),
      ('Vol. promedio 20 d', avgVol == null ? '—' : Fmt.compact(avgVol)),
    ]);
  }
}

class _OpenOrderTile extends StatelessWidget {
  final OrderInfo order;
  final VoidCallback onCancel;
  const _OpenOrderTile({required this.order, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final scheme = Theme.of(context).colorScheme;
    final details = [
      o.typeLabel + o.classLabel,
      if (o.limitPrice != null) 'límite ${Fmt.usd(o.limitPrice!)}',
      if (o.stopPrice != null) 'stop ${Fmt.usd(o.stopPrice!)}',
      if (o.trailPercent != null) 'trailing ${Fmt.number(o.trailPercent!)}%',
      o.statusLabel,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${o.isBuy ? "Compra" : "Venta"} · '
          '${o.qty != null ? Fmt.qty(o.qty!) : Fmt.usd(o.notional ?? 0)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(details, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        trailing: TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 10, height: 3, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

class _RangeSelector extends StatelessWidget {
  final ChartRange value;
  final ValueChanged<ChartRange> onChanged;
  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ChartRange.values
          .map((r) => ChoiceChip(
                label: Text(r.label),
                selected: r == value,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(r),
              ))
          .toList(),
    );
  }
}

class _RangeChangeText extends StatelessWidget {
  final List<PriceBar> bars;
  final ChartRange range;
  const _RangeChangeText({required this.bars, required this.range});

  @override
  Widget build(BuildContext context) {
    final first = range == ChartRange.day1 ? bars.first.open : bars.first.close;
    final last = bars.last.close;
    final pct = first == 0 ? 0.0 : (last - first) / first * 100;
    final color = pct >= 0 ? AppTheme.up : AppTheme.down;
    return Text(
      'En ${range.label}: ${Fmt.usdSigned(last - first)} (${Fmt.pct(pct)})',
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    );
  }
}

class _ChartTypeSelector extends StatelessWidget {
  final ChartStyle value;
  final ValueChanged<ChartStyle> onChanged;
  const _ChartTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChartStyle>(
      segments: const [
        ButtonSegment(value: ChartStyle.line, label: Text('Línea'), icon: Icon(Icons.show_chart_rounded, size: 16)),
        ButtonSegment(value: ChartStyle.area, label: Text('Área'), icon: Icon(Icons.area_chart_rounded, size: 16)),
        ButtonSegment(value: ChartStyle.candlestick, label: Text('Velas'), icon: Icon(Icons.candlestick_chart_rounded, size: 16)),
        ButtonSegment(value: ChartStyle.bar, label: Text('Barras'), icon: Icon(Icons.bar_chart_rounded, size: 16)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

String _formatTime(DateTime t, ChartRange range) {
  final local = t.toLocal();
  return switch (range) {
    ChartRange.day1 => DateFormat('HH:mm').format(local),
    ChartRange.week1 => DateFormat('EEE d, HH:mm', 'es').format(local),
    ChartRange.year5 => DateFormat('MMM yyyy', 'es').format(local),
    _ => DateFormat('d MMM yy', 'es').format(local),
  };
}

class _PriceChart extends StatelessWidget {
  final List<PriceBar> bars;
  final ChartStyle style;
  final ChartRange range;
  final bool showSma;
  const _PriceChart({required this.bars, required this.style, required this.range, required this.showSma});

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ChartStyle.candlestick:
        return _CandlestickView(bars: bars, range: range);
      case ChartStyle.bar:
        return _BarView(bars: bars, range: range);
      case ChartStyle.line:
      case ChartStyle.area:
        return _LineAreaView(bars: bars, filled: style == ChartStyle.area, range: range, showSma: showSma);
    }
  }
}

class _LineAreaView extends StatelessWidget {
  final List<PriceBar> bars;
  final bool filled;
  final ChartRange range;
  final bool showSma;
  const _LineAreaView({required this.bars, required this.filled, required this.range, required this.showSma});

  List<FlSpot> _smaSpots(List<double> closes, int period) {
    final s = Indicators.smaSeries(closes, period);
    return List.generate(s.length, (i) => s[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), s[i]!));
  }

  @override
  Widget build(BuildContext context) {
    final closes = bars.map((b) => b.close).toList();
    final isUp = closes.last >= closes.first;
    final color = isUp ? AppTheme.up : AppTheme.down;
    final spots = List.generate(bars.length, (i) => FlSpot(i.toDouble(), closes[i]));
    final minY = closes.reduce((a, b) => a < b ? a : b);
    final maxY = closes.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.1 + 0.01;
    final drawSma = showSma && bars.length > 20;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              if (s.barIndex == 0) {
                final bar = bars[s.x.toInt()];
                return LineTooltipItem(
                  '${_formatTime(bar.time, range)}\n${Fmt.usd(bar.close)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                );
              }
              return LineTooltipItem(
                '${s.barIndex == 1 ? "MM20" : "MM50"} ${Fmt.usd(s.y)}',
                TextStyle(color: s.barIndex == 1 ? _sma20Color : _sma50Color, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: filled, color: color.withValues(alpha: 0.14)),
          ),
          if (drawSma)
            LineChartBarData(
              spots: _smaSpots(closes, 20),
              color: _sma20Color,
              barWidth: 1.2,
              dotData: const FlDotData(show: false),
            ),
          if (drawSma && bars.length > 50)
            LineChartBarData(
              spots: _smaSpots(closes, 50),
              color: _sma50Color,
              barWidth: 1.2,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  final List<PriceBar> bars;
  const _VolumeChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final maxV = bars.map((b) => b.volume).fold<double>(0, (a, b) => a > b ? a : b);
    if (maxV == 0) return const SizedBox.shrink();
    return BarChart(
      BarChartData(
        maxY: maxV,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: List.generate(
          bars.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bars[i].volume,
                color: (bars[i].close >= bars[i].open ? AppTheme.up : AppTheme.down)
                    .withValues(alpha: 0.45),
                width: bars.length > 120 ? 1 : (bars.length > 40 ? 2 : 4),
                borderRadius: BorderRadius.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandlestickView extends StatelessWidget {
  final List<PriceBar> bars;
  final ChartRange range;
  const _CandlestickView({required this.bars, required this.range});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(
      bars.length,
      (i) => CandlestickSpot(
        x: i.toDouble(),
        open: bars[i].open,
        high: bars[i].high,
        low: bars[i].low,
        close: bars[i].close,
      ),
    );
    final minY = bars.map((b) => b.low).reduce((a, b) => a < b ? a : b);
    final maxY = bars.map((b) => b.high).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.08 + 0.01;

    return CandlestickChart(
      CandlestickChartData(
        candlestickSpots: spots,
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        candlestickPainter: DefaultCandlestickPainter(),
        candlestickTouchData: CandlestickTouchData(
          touchTooltipData: CandlestickTouchTooltipData(
            getTooltipItems: (painter, touchedSpot, spotIndex) {
              final bar = bars[spotIndex];
              return CandlestickTooltipItem(
                '${_formatTime(bar.time, range)}\n'
                'A ${Fmt.usd(bar.open)}  C ${Fmt.usd(bar.close)}\n'
                'Máx ${Fmt.usd(bar.high)}  Mín ${Fmt.usd(bar.low)}',
                bottomMargin: 4,
                textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BarView extends StatelessWidget {
  final List<PriceBar> bars;
  final ChartRange range;
  const _BarView({required this.bars, required this.range});

  @override
  Widget build(BuildContext context) {
    final isUp = bars.last.close >= bars.first.close;
    final color = isUp ? AppTheme.up : AppTheme.down;
    final minY = bars.map((b) => b.close).reduce((a, b) => a < b ? a : b);
    final maxY = bars.map((b) => b.close).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.1 + 0.01;
    final base = (minY - pad).clamp(0, double.infinity).toDouble();

    return BarChart(
      BarChartData(
        minY: base,
        maxY: maxY + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bar = bars[group.x];
              return BarTooltipItem(
                '${_formatTime(bar.time, range)}\n${Fmt.usd(bar.close)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              );
            },
          ),
        ),
        barGroups: List.generate(
          bars.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: bars[i].close,
                fromY: base,
                color: color,
                width: bars.length > 120 ? 1 : (bars.length > 30 ? 3 : 6),
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final NewsItem item;
  const _NewsTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('d MMM, HH:mm', 'es');
    return Card(
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: item.isAnalystCoverage
            ? BorderSide(color: scheme.primary.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(item.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${item.source} · ${formatter.format(item.createdAt)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            if (item.isAnalystCoverage) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '📊 Análisis de analistas',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary),
                ),
              ),
            ],
          ],
        ),
        isThreeLine: item.isAnalystCoverage,
        onTap: () {
          final uri = Uri.tryParse(item.url);
          if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}
