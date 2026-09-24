class PortfolioPoint {
  final DateTime time;
  final double equity;

  const PortfolioPoint({required this.time, required this.equity});
}

class PortfolioHistory {
  final List<PortfolioPoint> points;

  const PortfolioHistory({required this.points});

  double get change => points.isEmpty ? 0 : points.last.equity - points.first.equity;

  double get changePercent => points.isEmpty || points.first.equity == 0
      ? 0
      : change / points.first.equity * 100;

  factory PortfolioHistory.fromJson(Map<String, dynamic> json) {
    final ts = (json['timestamp'] as List?) ?? const [];
    final eq = (json['equity'] as List?) ?? const [];
    final points = <PortfolioPoint>[];
    for (var i = 0; i < ts.length && i < eq.length; i++) {
      final e = (eq[i] as num?)?.toDouble();
      // Alpaca rellena con null/0 los tramos sin datos (antes de que
      // existiera la cuenta); los saltamos para no dibujar caídas falsas a 0.
      if (e == null || e == 0) continue;
      points.add(PortfolioPoint(
        time: DateTime.fromMillisecondsSinceEpoch((ts[i] as num).toInt() * 1000),
        equity: e,
      ));
    }
    return PortfolioHistory(points: points);
  }
}
