enum AlertDirection { above, below }

enum AlertType {
  /// El precio llega a un valor.
  price,

  /// La variación del día supera un %.
  dayChange,

  /// El volumen de hoy supera N veces el de ayer.
  volumeSpike,

  /// El precio cruza su media móvil simple de N días.
  smaCross,
}

class PriceAlert {
  final String id;
  final String symbol;
  final AlertType type;
  final AlertDirection direction;

  /// Precio (price), porcentaje (dayChange), multiplicador (volumeSpike) o
  /// cantidad de días de la media (smaCross).
  final double target;

  /// Si es true la alerta no se desactiva al cumplirse: puede volver a
  /// sonar, como máximo una vez por día.
  final bool repeating;
  final DateTime createdAt;
  final bool triggered;
  final DateTime? triggeredAt;

  const PriceAlert({
    required this.id,
    required this.symbol,
    this.type = AlertType.price,
    required this.direction,
    required this.target,
    required this.createdAt,
    this.repeating = false,
    this.triggered = false,
    this.triggeredAt,
  });

  /// Sigue vigilándose (no es de un solo uso ya cumplida).
  bool get isActive => !triggered || repeating;

  bool get isAbove => direction == AlertDirection.above;

  String get description {
    final t = target;
    return switch (type) {
      AlertType.price =>
        '$symbol ${isAbove ? "sube a" : "baja a"} US\$${t.toStringAsFixed(2)}',
      AlertType.dayChange =>
        '$symbol ${isAbove ? "sube" : "cae"} ${t.toStringAsFixed(1)}% o más en el día',
      AlertType.volumeSpike =>
        'Volumen de $symbol ≥ ${t.toStringAsFixed(1)}x el de ayer',
      AlertType.smaCross =>
        '$symbol cruza ${isAbove ? "sobre" : "bajo"} su media de ${t.toInt()} días',
    };
  }

  PriceAlert copyWith({bool? triggered, DateTime? triggeredAt}) => PriceAlert(
        id: id,
        symbol: symbol,
        type: type,
        direction: direction,
        target: target,
        createdAt: createdAt,
        repeating: repeating,
        triggered: triggered ?? this.triggered,
        triggeredAt: triggeredAt ?? this.triggeredAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'type': type.name,
        'direction': direction.name,
        'targetPrice': target,
        'createdAt': createdAt.toIso8601String(),
        'repeating': repeating,
        'triggered': triggered,
        'triggeredAt': triggeredAt?.toIso8601String(),
      };

  // Compatible con las alertas guardadas por versiones anteriores (que no
  // tenían 'type' ni 'repeating').
  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        type: AlertType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AlertType.price,
        ),
        direction: AlertDirection.values.firstWhere((d) => d.name == json['direction']),
        target: (json['targetPrice'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        repeating: json['repeating'] as bool? ?? false,
        triggered: json['triggered'] as bool? ?? false,
        triggeredAt: json['triggeredAt'] != null
            ? DateTime.parse(json['triggeredAt'] as String)
            : null,
      );
}
