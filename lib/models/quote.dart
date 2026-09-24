class Quote {
  final String symbol;
  final double price;
  final double previousClose;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? previousVolume;
  final double? bid;
  final double? ask;

  const Quote({
    required this.symbol,
    required this.price,
    required this.previousClose,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.previousVolume,
    this.bid,
    this.ask,
  });

  double get change => price - previousClose;

  double get changePercent =>
      previousClose == 0 ? 0 : (change / previousClose) * 100;

  bool get isUp => change >= 0;

  /// Volumen de hoy dividido por el de ayer (1.0 = igual). null si faltan
  /// datos.
  double? get volumeRatio =>
      (volume == null || previousVolume == null || previousVolume == 0)
          ? null
          : volume! / previousVolume!;

  double? get spread =>
      (bid != null && ask != null && bid! > 0 && ask! > 0) ? ask! - bid! : null;

  /// Copia con un nuevo precio (lo usa el stream en tiempo real, que solo
  /// trae el último trade).
  Quote withPrice(double newPrice) => Quote(
        symbol: symbol,
        price: newPrice,
        previousClose: previousClose,
        open: open,
        high: high == null ? null : (newPrice > high! ? newPrice : high),
        low: low == null ? null : (newPrice < low! ? newPrice : low),
        volume: volume,
        previousVolume: previousVolume,
        bid: bid,
        ask: ask,
      );

  /// Construye la cotización desde un snapshot de Alpaca
  /// (`/v2/stocks/snapshots`). Devuelve null si falta precio o cierre previo.
  static Quote? fromSnapshot(String symbol, Map<String, dynamic> map) {
    double? pick(Map<String, dynamic>? m, String k) => (m?[k] as num?)?.toDouble();
    final latestTrade = map['latestTrade'] as Map<String, dynamic>?;
    final latestQuote = map['latestQuote'] as Map<String, dynamic>?;
    final prevDailyBar = map['prevDailyBar'] as Map<String, dynamic>?;
    final dailyBar = map['dailyBar'] as Map<String, dynamic>?;
    final price = pick(latestTrade, 'p') ?? pick(dailyBar, 'c');
    final prevClose = pick(prevDailyBar, 'c');
    if (price == null || prevClose == null) return null;
    return Quote(
      symbol: symbol,
      price: price,
      previousClose: prevClose,
      open: pick(dailyBar, 'o'),
      high: pick(dailyBar, 'h'),
      low: pick(dailyBar, 'l'),
      volume: pick(dailyBar, 'v'),
      previousVolume: pick(prevDailyBar, 'v'),
      bid: pick(latestQuote, 'bp'),
      ask: pick(latestQuote, 'ap'),
    );
  }
}
