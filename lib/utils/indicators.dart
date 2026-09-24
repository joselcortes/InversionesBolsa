import 'dart:math' as math;

/// Indicadores técnicos simples calculados sobre cierres.
class Indicators {
  /// Media móvil simple. Devuelve una lista del mismo largo que [values],
  /// con null en las posiciones donde todavía no hay [period] datos.
  static List<double?> smaSeries(List<double> values, int period) {
    final out = List<double?>.filled(values.length, null);
    if (period <= 0 || values.length < period) return out;
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= period) sum -= values[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  /// Media de los últimos [period] valores, o null si no alcanzan.
  static double? sma(List<double> values, int period) {
    if (period <= 0 || values.length < period) return null;
    final tail = values.sublist(values.length - period);
    return tail.reduce((a, b) => a + b) / period;
  }

  /// RSI de Wilder (0-100). Sobre 70 suele leerse como "sobrecompra" y bajo
  /// 30 como "sobreventa".
  static double? rsi(List<double> closes, [int period = 14]) {
    if (closes.length <= period) return null;
    var gain = 0.0;
    var loss = 0.0;
    for (var i = 1; i <= period; i++) {
      final d = closes[i] - closes[i - 1];
      if (d >= 0) {
        gain += d;
      } else {
        loss -= d;
      }
    }
    var avgGain = gain / period;
    var avgLoss = loss / period;
    for (var i = period + 1; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      avgGain = (avgGain * (period - 1) + math.max(d, 0)) / period;
      avgLoss = (avgLoss * (period - 1) + math.max(-d, 0)) / period;
    }
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - 100 / (1 + rs);
  }

  static String rsiLabel(double rsi) {
    if (rsi >= 70) return 'Sobrecompra';
    if (rsi <= 30) return 'Sobreventa';
    return 'Neutral';
  }

  /// Volatilidad anualizada (%) a partir de retornos diarios.
  static double? annualVolatility(List<double> closes) {
    if (closes.length < 10) return null;
    final returns = <double>[];
    for (var i = 1; i < closes.length; i++) {
      if (closes[i - 1] == 0) continue;
      returns.add(math.log(closes[i] / closes[i - 1]));
    }
    if (returns.length < 2) return null;
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns
            .map((r) => (r - mean) * (r - mean))
            .reduce((a, b) => a + b) /
        (returns.length - 1);
    return math.sqrt(variance) * math.sqrt(252) * 100;
  }
}
