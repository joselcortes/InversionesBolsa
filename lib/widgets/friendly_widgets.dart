import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content/glossary.dart';
import '../providers/portfolio_provider.dart';
import '../screens/learn_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Abre la explicación simple de un término del glosario.
Future<void> showTermSheet(BuildContext context, String termId) {
  final e = Glossary.byId(termId);
  if (e == null) return Future.value();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lightbulb_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(e.short, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const SizedBox(height: 14),
            Text(e.body, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen()));
              },
              icon: const Icon(Icons.school_rounded),
              label: const Text('Ver todas las explicaciones'),
            ),
          ],
        ),
      );
    },
  );
}

/// Iconito ⓘ que abre la explicación de un término.
class InfoTip extends StatelessWidget {
  final String term;
  final double size;
  const InfoTip(this.term, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showTermSheet(context, term),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline_rounded,
          size: size,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Texto + ⓘ en una fila (para etiquetas).
class LabelWithTip extends StatelessWidget {
  final String label;
  final String term;
  final TextStyle? style;
  const LabelWithTip(this.label, this.term, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, style: style ?? TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ),
        InfoTip(term, size: 15),
      ],
    );
  }
}

/// Enlace "¿Qué es esto?" para poner bajo un control.
class HelpLink extends StatelessWidget {
  final String text;
  final String term;
  const HelpLink(this.term, {super.key, this.text = '¿Qué es esto?'});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => showTermSheet(context, term),
      icon: const Icon(Icons.help_outline_rounded, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Tarjeta que destaca una ganancia o pérdida con color, flecha y una frase
/// simple ("Hoy ganaste…" / "Hoy perdiste…").
class GainLossCard extends StatelessWidget {
  /// Ej: "Hoy" o "Desde que compraste".
  final String period;
  final double usd;
  final double? percent;
  final String term;
  final String? footnote;

  const GainLossCard({
    super.key,
    required this.period,
    required this.usd,
    this.percent,
    required this.term,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final flat = usd.abs() < 0.005;
    final up = usd >= 0;
    final color = flat ? scheme.onSurfaceVariant : (up ? AppTheme.up : AppTheme.down);
    final verb = flat ? 'sin cambios' : (up ? 'ganaste' : 'perdiste');
    final icon = flat
        ? Icons.remove_rounded
        : (up ? Icons.trending_up_rounded : Icons.trending_down_rounded);
    final amount = provider.hideBalances
        ? Fmt.hiddenMask
        : provider.main(usd.abs());
    final other = provider.secondary(usd.abs());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: flat ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('$period $verb',
                          style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                    ),
                    InfoTip(term, size: 15),
                  ],
                ),
                Text(
                  flat ? amount : '${up ? "+" : "−"}$amount',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  [
                    if (percent != null) Fmt.pct(percent!),
                    ?other,
                  ].join(' · '),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (footnote != null) ...[
                  const SizedBox(height: 4),
                  Text(footnote!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto de monto con signo coloreado (verde/rojo).
class SignedAmount extends StatelessWidget {
  final double usd;
  final double? percent;
  final double fontSize;
  const SignedAmount({super.key, required this.usd, this.percent, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final color = usd >= 0 ? AppTheme.up : AppTheme.down;
    return Text(
      [provider.mainSigned(usd), if (percent != null) '(${Fmt.pct(percent!)})'].join(' '),
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: fontSize),
    );
  }
}
