class PriceBar {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const PriceBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  factory PriceBar.fromJson(Map<String, dynamic> json) => PriceBar(
        time: DateTime.parse(json['t'] as String),
        open: (json['o'] as num).toDouble(),
        high: (json['h'] as num).toDouble(),
        low: (json['l'] as num).toDouble(),
        close: (json['c'] as num).toDouble(),
        volume: (json['v'] as num?)?.toDouble() ?? 0,
      );
}
