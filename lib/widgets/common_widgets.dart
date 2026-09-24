import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/market_clock.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'friendly_widgets.dart';

class ChangeChip extends StatelessWidget {
  final double changePercent;

  const ChangeChip({super.key, required this.changePercent});

  @override
  Widget build(BuildContext context) {
    final isUp = changePercent >= 0;
    final color = isUp ? AppTheme.up : AppTheme.down;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            Fmt.pct(changePercent),
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LiveModeBanner extends StatelessWidget {
  const LiveModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.down,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'MODO REAL: las órdenes usan tu dinero de verdad',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Mercado abierto · cierra en 2 h 10 min" / "Cerrado · abre lun 10:30".
class MarketStatusBar extends StatelessWidget {
  final MarketClock? clock;
  final bool streaming;
  final DateTime? lastUpdated;

  const MarketStatusBar({super.key, required this.clock, this.streaming = false, this.lastUpdated});

  static String describe(MarketClock c) {
    String span(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      if (h >= 24) return '${d.inDays} d';
      return h > 0 ? '$h h $m min' : '$m min';
    }

    final now = DateTime.now();
    if (c.isOpen) return 'Mercado abierto · cierra en ${span(c.nextClose.difference(now))}';
    final sameDay = c.nextOpen.day == now.day && c.nextOpen.month == now.month;
    final when = sameDay
        ? 'hoy ${DateFormat('HH:mm').format(c.nextOpen)}'
        : DateFormat("EEE d 'a las' HH:mm", 'es').format(c.nextOpen);
    return 'Mercado cerrado · abre $when';
  }

  @override
  Widget build(BuildContext context) {
    final c = clock;
    if (c == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = c.isOpen ? AppTheme.up : scheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.surfaceContainerHigh,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(describe(c),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          ),
          if (streaming)
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.up),
                Text('En vivo', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            )
          else if (lastUpdated != null)
            Text('Act. ${DateFormat('HH:mm').format(lastUpdated!)}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Grilla de pares "etiqueta / valor" (estadísticas clave).
class StatGrid extends StatelessWidget {
  final List<(String, String)> items;

  /// Etiqueta → id del glosario, para mostrar un ⓘ junto a la etiqueta.
  final Map<String, String> tips;
  const StatGrid({super.key, required this.items, this.tips = const {}});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((e) => SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tips[e.$1] != null)
                        LabelWithTip(e.$1, tips[e.$1]!,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
                      else
                        Text(e.$1, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(e.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                ))
            .toList(),
      );
    });
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Pantalla vacía estándar cuando no hay cuenta conectada.
class NotConnectedScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  const NotConnectedScaffold({super.key, required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: EmptyState(icon: icon, title: 'Conecta tu cuenta de Alpaca', message: message),
      ),
    );
  }
}

/// Pide confirmación con un diálogo simple. Devuelve true si se aceptó.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.down) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r == true;
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
