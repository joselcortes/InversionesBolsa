import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import 'stock_detail_screen.dart';
import 'symbol_search_sheet.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  Future<void> _addSymbol(BuildContext context) async {
    final provider = context.read<PortfolioProvider>();
    final symbol = await showSymbolSearch(context, title: 'Agregar a tu lista');
    if (symbol == null || !context.mounted) return;
    final err = await provider.addToWatchlist(symbol);
    if (err != null && context.mounted) showSnack(context, err);
  }

  Future<void> _remove(BuildContext context, String symbol) async {
    final provider = context.read<PortfolioProvider>();
    final index = await provider.removeFromWatchlist(symbol);
    if (!context.mounted) return;
    showSnack(
      context,
      '$symbol quitado de tu lista',
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () => provider.insertInWatchlist(index, symbol),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (!provider.isConfigured) {
      return const NotConnectedScaffold(
        title: 'Mercado',
        icon: Icons.candlestick_chart_rounded,
        message: 'Ve a Ajustes para ingresar tus API keys y ver precios en vivo.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mercado'),
        actions: [
          IconButton(
            tooltip: 'Agregar acción',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addSymbol(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.isLive) const LiveModeBanner(),
          MarketStatusBar(
            clock: provider.clock,
            streaming: provider.streamConnected,
            lastUpdated: provider.lastUpdated,
          ),
          if (provider.error != null)
            Container(
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                provider.error!,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refreshAll,
              child: provider.watchlist.isEmpty
                  ? ListView(
                      children: [
                        EmptyState(
                          icon: Icons.list_alt_rounded,
                          title: 'Sin acciones en tu lista',
                          message: 'Busca por símbolo o nombre de empresa para seguirlas.',
                          actionLabel: 'Buscar acción',
                          onAction: () => _addSymbol(context),
                        ),
                      ],
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: provider.watchlist.length,
                      onReorderItem: provider.reorderWatchlist,
                      header: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Mantén presionado para reordenar · desliza para quitar',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      itemBuilder: (context, i) {
                        final symbol = provider.watchlist[i];
                        return Padding(
                          key: ValueKey(symbol),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey('dismiss-$symbol'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.down.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) => _remove(context, symbol),
                            child: _WatchTile(symbol: symbol),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchTile extends StatelessWidget {
  final String symbol;
  const _WatchTile({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final quote = provider.quotes[symbol];
    final name = provider.assetInfo(symbol)?.name;
    final owned = provider.positionFor(symbol) != null;
    final volRatio = quote?.volumeRatio;

    return Card(
      color: scheme.surfaceContainerHigh,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol)),
        ),
        title: Row(
          children: [
            Text(symbol, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            if (owned) ...[
              const SizedBox(width: 6),
              Icon(Icons.work_rounded, size: 13, color: scheme.primary),
            ],
            if (volRatio != null && volRatio >= 1.5) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Vol ${Fmt.number(volRatio)}x',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            if (name != null && name.isNotEmpty) name,
            if (quote != null) Fmt.usd(quote.price) else 'Cargando…',
          ].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
        isThreeLine: name != null && name.isNotEmpty,
        trailing: quote == null
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ChangeChip(changePercent: quote.changePercent),
      ),
    );
  }
}
