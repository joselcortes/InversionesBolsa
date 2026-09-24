import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/market_clock.dart';
import '../models/position.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'learn_screen.dart';
import 'settings_screen.dart';
import 'stock_detail_screen.dart';

/// Resumen simple: cuánto dinero tienes (en pesos), cuánto ganaste o
/// perdiste, y cómo va cada acción, en palabras simples.
class HomeScreen extends StatelessWidget {
  /// Para saltar a otra pestaña (ej. Mercado) desde los botones.
  final ValueChanged<int>? onGoToTab;
  const HomeScreen({super.key, this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          if (provider.isConfigured)
            IconButton(
              tooltip: provider.hideBalances ? 'Mostrar saldos' : 'Ocultar saldos',
              icon: Icon(provider.hideBalances ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: provider.toggleHideBalances,
            ),
          IconButton(
            tooltip: 'Aprende',
            icon: const Icon(Icons.school_rounded),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
          ),
        ],
      ),
      body: !provider.isConfigured
          ? const _Welcome()
          : RefreshIndicator(
              onRefresh: provider.refreshAll,
              child: provider.account == null
                  ? ListView(
                      children: [
                        if (provider.error != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: InfoBanner('No pudimos cargar tu cuenta: ${provider.error}',
                                icon: Icons.wifi_off_rounded),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    )
                  : _Summary(onGoToTab: onGoToTab),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  final ValueChanged<int>? onGoToTab;
  const _Summary({this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final account = provider.account!;
    final positions = [...provider.positions]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final cost = provider.totalCostBasis;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _ModeBanner(isLive: provider.isLive),
        const SizedBox(height: 12),
        _MarketSentence(clock: provider.clock),
        const SizedBox(height: 16),

        // ---------------------------------------------------- Saldo total
        Card(
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
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (provider.secondary(account.portfolioValue) != null)
                  Text(
                    provider.showsClpFirst
                        ? 'Son ${provider.secondary(account.portfolioValue)} (tu cuenta está en dólares)'
                        : provider.secondary(account.portfolioValue)!,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                if (provider.usdClp != null && provider.settings.showClp) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Dólar hoy: ${Fmt.clp(provider.usdClp!)}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      const InfoTip('dolar', size: 14),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ------------------------------------------- Ganancias / pérdidas
        GainLossCard(
          period: 'Hoy',
          usd: account.dayChange,
          percent: account.dayChangePercent,
          term: 'ganancia_hoy',
        ),
        if (positions.isNotEmpty) ...[
          const SizedBox(height: 12),
          GainLossCard(
            period: 'Desde que compraste',
            usd: provider.totalUnrealizedPl,
            percent: cost == 0 ? null : provider.totalUnrealizedPl / cost * 100,
            term: 'ganancia_total',
            footnote: 'Es lo que ganarías o perderías si vendieras todo hoy.',
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SimpleRow(
                  icon: Icons.show_chart_rounded,
                  label: 'Tus acciones valen hoy',
                  term: 'saldo_total',
                  value: provider.main(provider.totalMarketValue),
                ),
                const Divider(height: 20),
                _SimpleRow(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Pagaste por ellas',
                  term: 'invertido',
                  value: provider.main(cost),
                ),
                const Divider(height: 20),
                _SimpleRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Disponible para invertir',
                  term: 'efectivo',
                  value: provider.main(account.cash),
                ),
              ],
            ),
          ),
        ),

        // --------------------------------------------- Lo destacado de hoy
        if (positions.length > 1) ...[
          const SizedBox(height: 24),
          _Highlights(positions: positions),
        ],

        // ------------------------------------------------------ Acciones
        const SizedBox(height: 24),
        SectionTitle(
          'Así van tus acciones',
          trailing: const InfoTip('accion'),
        ),
        if (positions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Todavía no tienes acciones.', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Ve a Mercado, busca una empresa que conozcas (por ejemplo Apple) y presiona Comprar. '
                    'Si estás en modo práctica, no arriesgas dinero real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => onGoToTab?.call(1),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Buscar acciones'),
                  ),
                ],
              ),
            ),
          )
        else
          ...positions.map((p) => _PositionCard(position: p)),

        // ------------------------------------------------------- Leyenda
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Cómo leer esto?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const _Legend(color: AppTheme.up, text: 'Verde = vas ganando'),
              const _Legend(color: AppTheme.down, text: 'Rojo = vas perdiendo'),
              const SizedBox(height: 6),
              Text(
                provider.showsClpFirst
                    ? 'Los montos en pesos son aproximados: usamos el dólar observado de hoy.'
                    : 'Los montos están en dólares (US\$).',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              HelpLink('ganancia_total', text: 'Aprende más sobre ganancias y pérdidas'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SimpleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String term;
  final String value;
  const _SimpleRow({required this.icon, required this.label, required this.term, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(child: LabelWithTip(label, term, style: const TextStyle(fontSize: 14))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      );
}

class _ModeBanner extends StatelessWidget {
  final bool isLive;
  const _ModeBanner({required this.isLive});

  @override
  Widget build(BuildContext context) {
    final color = isLive ? AppTheme.down : AppTheme.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showTermSheet(context, 'paper'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(isLive ? '⚠️' : '🧪', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLive
                    ? 'Modo REAL: estás usando tu dinero de verdad.'
                    : 'Modo práctica: el dinero es simulado. Puedes aprender sin riesgo.',
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Icon(Icons.info_outline_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _MarketSentence extends StatelessWidget {
  final MarketClock? clock;
  const _MarketSentence({required this.clock});

  @override
  Widget build(BuildContext context) {
    final c = clock;
    if (c == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final hm = DateFormat('HH:mm');
    final now = DateTime.now();
    final sameDay = c.nextOpen.year == now.year && c.nextOpen.month == now.month && c.nextOpen.day == now.day;
    final text = c.isOpen
        ? 'La bolsa está abierta. Cierra hoy a las ${hm.format(c.nextClose)} (hora de Chile).'
        : 'La bolsa está cerrada. Abre ${sameDay ? "hoy" : DateFormat("EEEE d", "es").format(c.nextOpen)} '
            'a las ${hm.format(c.nextOpen)} (hora de Chile). Si compras ahora, se hace al abrir.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c.isOpen ? AppTheme.up : AppTheme.down,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: scheme.onSurface))),
        const InfoTip('bolsa'),
      ],
    );
  }
}

class _Highlights extends StatelessWidget {
  final List<Position> positions;
  const _Highlights({required this.positions});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final byToday = [...positions]..sort((a, b) => b.changeTodayPercent.compareTo(a.changeTodayPercent));
    final byTotal = [...positions]..sort((a, b) => b.unrealizedPlPercent.compareTo(a.unrealizedPlPercent));
    String name(Position p) {
      final n = provider.assetInfo(p.symbol)?.name;
      return n == null || n.isEmpty ? p.symbol : '${Fmt.shortName(n)} (${p.symbol})';
    }

    final best = byToday.first;
    final worst = byToday.last;
    final lines = <(String, String, Color)>[
      if (best.changeTodayPercent > 0)
        ('📈', 'La que más subió hoy: ${name(best)}, ${Fmt.pct(best.changeTodayPercent)}.', AppTheme.up),
      if (worst.changeTodayPercent < 0)
        ('📉', 'La que más bajó hoy: ${name(worst)}, ${Fmt.pct(worst.changeTodayPercent)}.', AppTheme.down),
      if (byTotal.first.unrealizedPl > 0)
        ('🏆', 'Tu mejor inversión: ${name(byTotal.first)}, '
            '${provider.mainSigned(byTotal.first.unrealizedPl)} desde que la compraste.', AppTheme.up),
      if (byTotal.last.unrealizedPl < 0)
        ('⚠️', 'La que va peor: ${name(byTotal.last)}, '
            '${provider.mainSigned(byTotal.last.unrealizedPl)}. Puedes protegerla con un stop-loss.',
            AppTheme.down),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Lo destacado'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l.$2, style: const TextStyle(fontSize: 14, height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Position position;
  const _PositionCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final p = position;
    final fullName = provider.assetInfo(p.symbol)?.name;
    final title = fullName == null || fullName.isEmpty ? p.symbol : Fmt.shortName(fullName);
    final totalUp = p.unrealizedPl >= 0;
    final color = totalUp ? AppTheme.up : AppTheme.down;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: p.symbol)),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        TextSpan(
                          text: '  ${p.symbol}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(provider.main(p.marketValue),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tienes ${Fmt.qty(p.qty)} ${p.qty == 1 ? "acción" : "acciones"} · cada una vale ${Fmt.usd(p.currentPrice)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniChange(label: 'Hoy', usd: p.unrealizedIntradayPl, pct: p.changeTodayPercent),
                  ),
                  Expanded(
                    child: _MiniChange(label: 'En total', usd: p.unrealizedPl, pct: p.unrealizedPlPercent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChange extends StatelessWidget {
  final String label;
  final double usd;
  final double pct;
  const _MiniChange({required this.label, required this.usd, required this.pct});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        SignedAmount(usd: usd, percent: pct, fontSize: 13),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: scheme.primary,
                child: Text(n, style: TextStyle(color: scheme.onPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('¡Hola! 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Esta app te ayuda a invertir en acciones de empresas de EE.UU. (como Apple o Coca-Cola) '
          'y te muestra todo en pesos chilenos, en palabras simples.',
          style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Para empezar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                step('1', 'Crea una cuenta gratis en alpaca.markets (tu corredora de bolsa).'),
                step('2', 'Genera tus claves (API keys) en modo práctica, para aprender sin arriesgar dinero.'),
                step('3', 'Pégalas en Ajustes de esta app y presiona Conectar.'),
                const SizedBox(height: 8),
                HelpLink('api_keys', text: 'Ver paso a paso cómo sacar las claves'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.link_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Conectar mi cuenta'),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
          icon: const Icon(Icons.school_rounded),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Aprender lo básico primero'),
          ),
        ),
      ],
    );
  }
}
