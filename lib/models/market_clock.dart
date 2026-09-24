class MarketClock {
  final bool isOpen;
  final DateTime nextOpen;
  final DateTime nextClose;

  /// Hora actual en Nueva York tal como la reporta Alpaca, guardada como
  /// "hora de pared" (año/mes/día/hora de NY) para decidir cosas como
  /// "¿ya cerró el mercado hoy?" sin depender de la zona del teléfono.
  final DateTime nyNow;

  const MarketClock({
    required this.isOpen,
    required this.nextOpen,
    required this.nextClose,
    required this.nyNow,
  });

  /// Convierte un timestamp ISO con offset (ej. `...-04:00`) en la hora de
  /// pared de esa zona.
  static DateTime wallTime(String iso) {
    final utc = DateTime.parse(iso).toUtc();
    final m = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(iso);
    if (m == null) return utc;
    final offset = Duration(
      hours: int.parse(m.group(2)!),
      minutes: int.parse(m.group(3)!),
    );
    final wall = m.group(1) == '-' ? utc.subtract(offset) : utc.add(offset);
    return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second);
  }

  factory MarketClock.fromJson(Map<String, dynamic> json) => MarketClock(
        isOpen: json['is_open'] as bool? ?? false,
        nextOpen: DateTime.parse(json['next_open'] as String).toLocal(),
        nextClose: DateTime.parse(json['next_close'] as String).toLocal(),
        nyNow: wallTime(json['timestamp'] as String),
      );
}
