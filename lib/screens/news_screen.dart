import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/portfolio_provider.dart';
import '../widgets/common_widgets.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _onlyAnalyst = false;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('d MMM, HH:mm', 'es');
    final source = _onlyMine ? provider.myNews : provider.news;
    final sorted = [...source]..sort((a, b) {
        if (a.isAnalystCoverage != b.isAnalystCoverage) {
          return a.isAnalystCoverage ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    final visible = _onlyAnalyst ? sorted.where((n) => n.isAnalystCoverage).toList() : sorted;

    if (!provider.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Noticias')),
        body: const Center(
          child: EmptyState(
            icon: Icons.newspaper_rounded,
            title: 'Conecta tu cuenta de Alpaca',
            message: 'Ve a Ajustes para ver las últimas noticias del mercado.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticias'),
        actions: [
          FilterChip(
            label: const Text('Mis acciones', style: TextStyle(fontSize: 12)),
            selected: _onlyMine,
            onSelected: (v) => setState(() => _onlyMine = v),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilterChip(
                label: const Text('Análisis', style: TextStyle(fontSize: 12)),
                selected: _onlyAnalyst,
                onSelected: (v) => setState(() => _onlyAnalyst = v),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshAll,
        child: visible.isEmpty
            ? ListView(
                children: const [
                  EmptyState(
                    icon: Icons.newspaper_rounded,
                    title: 'Sin noticias por ahora',
                    message: 'Desliza hacia abajo para actualizar.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = visible[i];
                  return Card(
                    color: scheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: item.isAnalystCoverage
                          ? BorderSide(color: scheme.primary.withValues(alpha: 0.4))
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(item.headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('${item.source} · ${formatter.format(item.createdAt)}',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (item.isAnalystCoverage)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('📊 Análisis',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary)),
                                ),
                              ...item.symbols.take(4).map((s) => Chip(
                                    label: Text(s, style: const TextStyle(fontSize: 11)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  )),
                            ],
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () {
                        final uri = Uri.tryParse(item.url);
                        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
