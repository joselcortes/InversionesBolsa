import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inversiones_bolsa/models/dca_plan.dart';
import 'package:inversiones_bolsa/models/market_clock.dart';
import 'package:inversiones_bolsa/models/order_info.dart';
import 'package:inversiones_bolsa/models/price_alert.dart';
import 'package:inversiones_bolsa/models/quote.dart';
import 'package:inversiones_bolsa/services/fx_service.dart';
import 'package:inversiones_bolsa/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('Quote.fromSnapshot lee precio, OHLC, volumen y bid/ask', () {
    final q = Quote.fromSnapshot('AAPL', {
      'latestTrade': {'p': 110.0},
      'latestQuote': {'bp': 109.9, 'ap': 110.1},
      'dailyBar': {'o': 101, 'h': 111, 'l': 100, 'c': 109, 'v': 2000},
      'prevDailyBar': {'c': 100, 'v': 1000},
    })!;
    expect(q.price, 110);
    expect(q.changePercent, closeTo(10, 1e-9));
    expect(q.volumeRatio, 2);
    expect(q.spread, closeTo(0.2, 1e-9));
    expect(Quote.fromSnapshot('X', {'latestTrade': {'p': 1}}), isNull);
  });

  test('Quote.withPrice actualiza máximos y mínimos', () {
    const q = Quote(symbol: 'A', price: 10, previousClose: 9, high: 11, low: 9.5);
    expect(q.withPrice(12).high, 12);
    expect(q.withPrice(9).low, 9);
  });

  test('las alertas guardadas por la versión anterior se siguen leyendo', () {
    final a = PriceAlert.fromJson({
      'id': 'x',
      'symbol': 'TSLA',
      'direction': 'below',
      'targetPrice': 200,
      'createdAt': '2026-01-01T00:00:00.000',
      'triggered': false,
    });
    expect(a.type, AlertType.price);
    expect(a.repeating, isFalse);
    expect(a.target, 200);
    final back = PriceAlert.fromJson(a.toJson());
    expect(back.direction, AlertDirection.below);
  });

  group('DcaPlan', () {
    final weekly = DcaPlan(
      id: 'p',
      symbol: 'VOO',
      amountUsd: 50,
      frequency: DcaFrequency.weekly,
      day: 3, // miércoles
      enabled: true,
      createdAt: DateTime(2026),
    );

    test('semanal: toca desde el día elegido y una vez por semana', () {
      final tue = DateTime(2026, 9, 22); // martes
      final wed = DateTime(2026, 9, 23);
      final fri = DateTime(2026, 9, 25);
      expect(weekly.isDue(tue), isFalse);
      expect(weekly.isDue(wed), isTrue);
      final done = weekly.copyWith(lastRunKey: weekly.periodKey(wed));
      expect(done.isDue(fri), isFalse, reason: 'ya se compró esta semana');
      expect(done.isDue(DateTime(2026, 9, 30)), isTrue, reason: 'semana siguiente');
    });

    test('mensual: si el día cae en feriado compra el siguiente día hábil', () {
      final monthly = DcaPlan(
        id: 'm',
        symbol: 'VOO',
        amountUsd: 100,
        frequency: DcaFrequency.monthly,
        day: 5,
        enabled: true,
        createdAt: DateTime(2026),
      );
      expect(monthly.isDue(DateTime(2026, 10, 4)), isFalse);
      expect(monthly.isDue(DateTime(2026, 10, 6)), isTrue);
      expect(monthly.copyWith(enabled: false).isDue(DateTime(2026, 10, 6)), isFalse);
    });
  });

  test('MarketClock.wallTime respeta el offset de Nueva York', () {
    final t = MarketClock.wallTime('2026-09-22T16:05:00.123-04:00');
    expect(t.hour, 16);
    expect(t.minute, 5);
    expect(t.day, 22);
  });

  test('OrderInfo reconoce órdenes abiertas', () {
    OrderInfo o(String status) => OrderInfo.fromJson({
          'id': 'abc',
          'symbol': 'AAPL',
          'side': 'buy',
          'status': status,
          'qty': '1',
          'created_at': '2026-01-01T00:00:00Z',
        });
    expect(o('new').isOpen, isTrue);
    expect(o('held').isOpen, isTrue);
    expect(o('filled').isOpen, isFalse);
    expect(o('canceled').isOpen, isFalse);
  });

  test('Fmt.parse acepta formato chileno y con punto', () {
    expect(Fmt.parse('1.234,56'), 1234.56);
    expect(Fmt.parse('1234.56'), 1234.56);
    expect(Fmt.parse('12,5'), 12.5);
    expect(Fmt.parse('US\$ 1,234.50'), 1234.5);
    expect(Fmt.parse(''), isNull);
  });

  test('Fmt oculta montos', () {
    expect(Fmt.usd(1234.5, hidden: true), Fmt.hiddenMask);
    expect(Fmt.usd(1234.5), contains('1.234,50'));
    expect(Fmt.clp(950000), contains('950.000'));
  });

  test('FxService.lookup usa el día hábil anterior', () {
    final series = {'2026-09-18': 950.0};
    expect(FxService.lookup(series, DateTime(2026, 9, 20)), 950);
    expect(FxService.lookup(series, DateTime(2026, 10, 20)), isNull);
  });
}
