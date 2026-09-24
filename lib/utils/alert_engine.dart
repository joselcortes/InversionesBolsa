import '../models/price_alert.dart';
import '../models/quote.dart';

/// Resultado de evaluar una alerta que se cumplió.
class AlertHit {
  final PriceAlert updated;
  final String message;
  const AlertHit(this.updated, this.message);
}

/// Lógica pura (sin red ni plugins) para decidir si una alerta se cumple.
/// La usan tanto la app abierta como la tarea en segundo plano, y es fácil
/// de testear.
class AlertEngine {
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// true si la alerta todavía puede sonar en [now].
  static bool canFire(PriceAlert alert, DateTime now) {
    if (!alert.triggered) return true;
    if (!alert.repeating) return false;
    final last = alert.triggeredAt;
    return last == null || !_sameDay(last, now);
  }

  /// [sma] solo se necesita para alertas de tipo [AlertType.smaCross]: es la
  /// media móvil de los últimos N cierres (sin contar hoy).
  static bool isMet(PriceAlert alert, Quote quote, {double? sma}) {
    final above = alert.isAbove;
    switch (alert.type) {
      case AlertType.price:
        return above ? quote.price >= alert.target : quote.price <= alert.target;
      case AlertType.dayChange:
        final pct = quote.changePercent;
        return above ? pct >= alert.target : pct <= -alert.target;
      case AlertType.volumeSpike:
        final ratio = quote.volumeRatio;
        return ratio != null && ratio >= alert.target;
      case AlertType.smaCross:
        if (sma == null) return false;
        // Cruce: ayer cerró del otro lado de la media y hoy la pasó.
        return above
            ? quote.previousClose < sma && quote.price >= sma
            : quote.previousClose > sma && quote.price <= sma;
    }
  }

  static String message(PriceAlert alert, Quote quote, {double? sma}) {
    final p = 'US\$${quote.price.toStringAsFixed(2)}';
    return switch (alert.type) {
      AlertType.price =>
        '${alert.symbol} ${alert.isAbove ? "subió" : "bajó"} a $p '
            '(objetivo: US\$${alert.target.toStringAsFixed(2)})',
      AlertType.dayChange =>
        '${alert.symbol} va ${quote.changePercent >= 0 ? "+" : ""}'
            '${quote.changePercent.toStringAsFixed(2)}% hoy ($p)',
      AlertType.volumeSpike =>
        '${alert.symbol} lleva ${quote.volumeRatio!.toStringAsFixed(1)}x el volumen de ayer ($p)',
      AlertType.smaCross =>
        '${alert.symbol} cruzó ${alert.isAbove ? "sobre" : "bajo"} su media de '
            '${alert.target.toInt()} días (US\$${sma!.toStringAsFixed(2)}) · ahora $p',
    };
  }

  /// Evalúa todas las alertas y devuelve las que sonaron (ya marcadas como
  /// cumplidas). [smas] mapea "SIMBOLO:N" → media de N días.
  static List<AlertHit> evaluate(
    List<PriceAlert> alerts,
    Map<String, Quote> quotes, {
    Map<String, double> smas = const {},
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final hits = <AlertHit>[];
    for (final alert in alerts) {
      if (!canFire(alert, t)) continue;
      final quote = quotes[alert.symbol];
      if (quote == null) continue;
      final sma = alert.type == AlertType.smaCross
          ? smas[smaKey(alert.symbol, alert.target.toInt())]
          : null;
      if (isMet(alert, quote, sma: sma)) {
        hits.add(AlertHit(
          alert.copyWith(triggered: true, triggeredAt: t),
          message(alert, quote, sma: sma),
        ));
      }
    }
    return hits;
  }

  static String smaKey(String symbol, int period) => '$symbol:$period';
}
