class AccountInfo {
  final double equity;
  final double cash;
  final double buyingPower;
  final double portfolioValue;
  final double lastEquity;
  final bool tradingBlocked;

  const AccountInfo({
    required this.equity,
    required this.cash,
    required this.buyingPower,
    required this.portfolioValue,
    required this.lastEquity,
    required this.tradingBlocked,
  });

  double get dayChange => equity - lastEquity;

  double get dayChangePercent =>
      lastEquity == 0 ? 0 : (dayChange / lastEquity) * 100;

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        equity: double.parse(json['equity'] as String),
        cash: double.parse(json['cash'] as String),
        buyingPower: double.parse(json['buying_power'] as String),
        portfolioValue: double.parse(json['portfolio_value'] as String),
        lastEquity: double.parse(json['last_equity'] as String),
        tradingBlocked: json['trading_blocked'] as bool? ?? false,
      );
}
