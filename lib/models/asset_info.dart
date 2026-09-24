class AssetInfo {
  final String symbol;
  final String name;
  final String exchange;
  final bool tradable;
  final bool fractionable;

  const AssetInfo({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.tradable,
    required this.fractionable,
  });

  factory AssetInfo.fromJson(Map<String, dynamic> json) => AssetInfo(
        symbol: json['symbol'] as String,
        name: json['name'] as String? ?? '',
        exchange: json['exchange'] as String? ?? '',
        tradable: json['tradable'] as bool? ?? false,
        fractionable: json['fractionable'] as bool? ?? false,
      );

  /// Formato compacto para el caché local (son miles de activos).
  List<dynamic> toCompact() =>
      [symbol, name, exchange, tradable ? 1 : 0, fractionable ? 1 : 0];

  factory AssetInfo.fromCompact(List<dynamic> c) => AssetInfo(
        symbol: c[0] as String,
        name: c[1] as String,
        exchange: c[2] as String,
        tradable: c[3] == 1,
        fractionable: c[4] == 1,
      );
}
