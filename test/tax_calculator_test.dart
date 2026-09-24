import 'package:flutter_test/flutter_test.dart';
import 'package:inversiones_bolsa/models/account_activity.dart';
import 'package:inversiones_bolsa/utils/tax_calculator.dart';

AccountActivity _fill(String side, DateTime d, double qty, double price) => AccountActivity(
      id: '${d.toIso8601String()}-$side',
      type: 'FILL',
      date: d,
      symbol: 'AAPL',
      side: side,
      qty: qty,
      price: price,
    );

void main() {
  test('FIFO: vende primero los lotes más antiguos y convierte a CLP con el dólar de cada fecha', () {
    final acts = [
      _fill('buy', DateTime(2024, 5, 1), 10, 100), // dólar 900
      _fill('buy', DateTime(2025, 2, 1), 10, 150), // dólar 950
      _fill('sell', DateTime(2025, 6, 1), 15, 200), // dólar 1000
    ];
    double fx(DateTime d) => d.year == 2024 ? 900 : (d.month == 2 ? 950 : 1000);

    final r = TaxCalculator.build(year: 2025, activities: acts, fxOn: fx);

    expect(r.sales, hasLength(1));
    final s = r.sales.single;
    // Costo: 10×100 + 5×150 = 1750; venta: 15×200 = 3000.
    expect(s.costUsd, 1750);
    expect(s.proceedsUsd, 3000);
    expect(s.gainUsd, 1250);
    // CLP: venta 3.000.000; costo 10×100×900 + 5×150×950 = 900.000 + 712.500.
    expect(s.proceedsClp, 3000000);
    expect(s.costClp, 1612500);
    expect(s.gainClp, 1387500);
    expect(r.missingFx, isFalse);
  });

  test('las ventas de otro año no entran, pero sí consumen lotes', () {
    final acts = [
      _fill('buy', DateTime(2023, 1, 5), 10, 10),
      _fill('buy', DateTime(2023, 1, 6), 10, 20),
      _fill('sell', DateTime(2024, 3, 1), 10, 30),
      _fill('sell', DateTime(2025, 3, 1), 10, 30),
    ];
    final r = TaxCalculator.build(year: 2025, activities: acts, fxOn: (_) => 1);
    expect(r.sales, hasLength(1));
    expect(r.sales.single.costUsd, 200, reason: 'el lote a US\$10 ya se vendió en 2024');
  });

  test('dividendos con retención del mismo símbolo', () {
    final acts = [
      AccountActivity(id: 'd', type: 'DIV', date: DateTime(2025, 4, 10), symbol: 'KO', netAmount: 10),
      AccountActivity(id: 'w', type: 'DIVNRA', date: DateTime(2025, 4, 10), symbol: 'KO', netAmount: -3),
    ];
    final r = TaxCalculator.build(year: 2025, activities: acts, fxOn: (_) => null);
    expect(r.dividends.single.grossUsd, 10);
    expect(r.dividends.single.withheldUsd, 3);
    expect(r.missingFx, isTrue);
    expect(r.toCsv(), contains('KO;10.00;3.00'));
  });
}
