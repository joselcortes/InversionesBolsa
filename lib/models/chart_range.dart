/// Rangos del gráfico de una acción.
enum ChartRange {
  day1('1D', '5Min', Duration(days: 5)),
  week1('1S', '1Hour', Duration(days: 7)),
  month1('1M', '1Day', Duration(days: 31)),
  month3('3M', '1Day', Duration(days: 92)),
  year1('1A', '1Day', Duration(days: 366)),
  year5('5A', '1Week', Duration(days: 366 * 5));

  final String label;
  final String timeframe;
  final Duration lookback;

  const ChartRange(this.label, this.timeframe, this.lookback);

  bool get isIntraday => this == ChartRange.day1 || this == ChartRange.week1;
}

/// Rangos del gráfico del portafolio (`/v2/account/portfolio/history`).
enum HistoryRange {
  day1('1D', '1D', '15Min'),
  week1('1S', '1W', '1H'),
  month1('1M', '1M', '1D'),
  month3('3M', '3M', '1D'),
  year1('1A', '1A', '1D'),
  all('Todo', '5A', '1D');

  final String label;
  final String period;
  final String timeframe;

  const HistoryRange(this.label, this.period, this.timeframe);
}
