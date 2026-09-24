enum DcaFrequency { weekly, monthly }

/// Plan de compra periódica: invertir un monto fijo en US$ cada cierto
/// tiempo, sin importar el precio (Dollar Cost Averaging).
class DcaPlan {
  final String id;
  final String symbol;
  final double amountUsd;
  final DcaFrequency frequency;

  /// 1 = lunes … 5 = viernes (semanal) o día del mes 1-28 (mensual).
  final int day;
  final bool enabled;
  final DateTime createdAt;
  final String? lastRunKey;

  const DcaPlan({
    required this.id,
    required this.symbol,
    required this.amountUsd,
    required this.frequency,
    required this.day,
    required this.enabled,
    required this.createdAt,
    this.lastRunKey,
  });

  static const weekdayNames = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes'];

  String get scheduleLabel => frequency == DcaFrequency.weekly
      ? 'Cada ${weekdayNames[day]}'
      : 'El día $day de cada mes';

  /// Identificador del periodo (semana o mes) al que corresponde [date].
  /// Se usa para no ejecutar dos veces la misma cuota.
  String periodKey(DateTime date) {
    if (frequency == DcaFrequency.monthly) {
      return '${date.year}${date.month.toString().padLeft(2, '0')}';
    }
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    return 'w${monday.year}${monday.month.toString().padLeft(2, '0')}'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  /// true si en [date] (hora de NY) toca ejecutar y aún no se ejecutó este
  /// periodo. Si el día programado cae en feriado, se ejecuta el siguiente
  /// día hábil del mismo periodo (por eso es ">=" y no "==").
  bool isDue(DateTime date) {
    if (!enabled) return false;
    if (lastRunKey == periodKey(date)) return false;
    if (frequency == DcaFrequency.weekly) {
      return date.weekday >= day && date.weekday <= 5;
    }
    return date.day >= day;
  }

  DcaPlan copyWith({bool? enabled, String? lastRunKey}) => DcaPlan(
        id: id,
        symbol: symbol,
        amountUsd: amountUsd,
        frequency: frequency,
        day: day,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
        lastRunKey: lastRunKey ?? this.lastRunKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'amountUsd': amountUsd,
        'frequency': frequency.name,
        'day': day,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'lastRunKey': lastRunKey,
      };

  factory DcaPlan.fromJson(Map<String, dynamic> json) => DcaPlan(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        amountUsd: (json['amountUsd'] as num).toDouble(),
        frequency: DcaFrequency.values.firstWhere(
          (f) => f.name == json['frequency'],
          orElse: () => DcaFrequency.weekly,
        ),
        day: json['day'] as int,
        enabled: json['enabled'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastRunKey: json['lastRunKey'] as String?,
      );
}
