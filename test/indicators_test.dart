import 'package:flutter_test/flutter_test.dart';
import 'package:inversiones_bolsa/utils/indicators.dart';

void main() {
  test('SMA simple y serie', () {
    final v = <double>[1, 2, 3, 4, 5];
    expect(Indicators.sma(v, 5), 3);
    expect(Indicators.sma(v, 2), 4.5);
    expect(Indicators.sma(v, 6), isNull);
    expect(Indicators.smaSeries(v, 3), [null, null, 2, 3, 4]);
  });

  test('RSI: solo subidas = 100, solo bajadas = 0', () {
    final up = List.generate(30, (i) => 100.0 + i);
    final down = List.generate(30, (i) => 100.0 - i);
    expect(Indicators.rsi(up), 100);
    expect(Indicators.rsi(down), closeTo(0, 1e-9));
    expect(Indicators.rsi([1, 2, 3]), isNull);
  });

  test('RSI alternado queda cerca de 50', () {
    final zigzag = List.generate(60, (i) => i.isEven ? 100.0 : 101.0);
    expect(Indicators.rsi(zigzag), closeTo(50, 5));
  });

  test('etiquetas de RSI', () {
    expect(Indicators.rsiLabel(75), 'Sobrecompra');
    expect(Indicators.rsiLabel(25), 'Sobreventa');
    expect(Indicators.rsiLabel(50), 'Neutral');
  });

  test('volatilidad de un precio constante es 0', () {
    expect(Indicators.annualVolatility(List.filled(30, 50.0)), 0);
  });
}
