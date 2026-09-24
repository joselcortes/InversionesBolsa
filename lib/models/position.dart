class Position {
  final String symbol;
  final double qty;

  /// Acciones libres para vender (las que no están comprometidas en otra
  /// orden abierta, como un stop-loss).
  final double qtyAvailable;
  final double avgEntryPrice;
  final double currentPrice;
  final double marketValue;
  final double costBasis;
  final double unrealizedPl;
  final double unrealizedPlPercent;
  final double unrealizedIntradayPl;
  final double changeTodayPercent;

  const Position({
    required this.symbol,
    required this.qty,
    double? qtyAvailable,
    required this.avgEntryPrice,
    required this.currentPrice,
    required this.marketValue,
    double? costBasis,
    required this.unrealizedPl,
    required this.unrealizedPlPercent,
    this.unrealizedIntradayPl = 0,
    this.changeTodayPercent = 0,
  })  : qtyAvailable = qtyAvailable ?? qty,
        costBasis = costBasis ?? qty * avgEntryPrice;

  static double _d(dynamic v, [double fallback = 0]) =>
      v == null ? fallback : double.tryParse(v.toString()) ?? fallback;

  factory Position.fromJson(Map<String, dynamic> json) {
    final qty = _d(json['qty']);
    return Position(
      symbol: json['symbol'] as String,
      qty: qty,
      qtyAvailable: _d(json['qty_available'], qty),
      avgEntryPrice: _d(json['avg_entry_price']),
      currentPrice: _d(json['current_price']),
      marketValue: _d(json['market_value']),
      costBasis: _d(json['cost_basis']),
      unrealizedPl: _d(json['unrealized_pl']),
      unrealizedPlPercent: _d(json['unrealized_plpc']) * 100,
      unrealizedIntradayPl: _d(json['unrealized_intraday_pl']),
      changeTodayPercent: _d(json['change_today']) * 100,
    );
  }
}
