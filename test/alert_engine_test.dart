import 'package:flutter_test/flutter_test.dart';
import 'package:inversiones_bolsa/models/price_alert.dart';
import 'package:inversiones_bolsa/models/quote.dart';
import 'package:inversiones_bolsa/utils/alert_engine.dart';

PriceAlert _alert({
  AlertType type = AlertType.price,
  AlertDirection direction = AlertDirection.above,
  double target = 100,
  bool repeating = false,
  bool triggered = false,
  DateTime? triggeredAt,
}) =>
    PriceAlert(
      id: 'a1',
      symbol: 'AAPL',
      type: type,
      direction: direction,
      target: target,
      repeating: repeating,
      triggered: triggered,
      triggeredAt: triggeredAt,
      createdAt: DateTime(2026, 1, 1),
    );

Quote _quote({double price = 105, double prev = 100, double? vol, double? prevVol}) => Quote(
      symbol: 'AAPL',
      price: price,
      previousClose: prev,
      volume: vol,
      previousVolume: prevVol,
    );

void main() {
  group('precio', () {
    test('sube a: se cumple sobre el objetivo', () {
      expect(AlertEngine.isMet(_alert(target: 100), _quote(price: 101)), isTrue);
      expect(AlertEngine.isMet(_alert(target: 100), _quote(price: 99)), isFalse);
    });

    test('baja a: se cumple bajo el objetivo', () {
      final a = _alert(direction: AlertDirection.below, target: 90);
      expect(AlertEngine.isMet(a, _quote(price: 89)), isTrue);
      expect(AlertEngine.isMet(a, _quote(price: 91)), isFalse);
    });
  });

  test('variación del día en ambas direcciones', () {
    final up = _alert(type: AlertType.dayChange, target: 5);
    final down = _alert(type: AlertType.dayChange, target: 5, direction: AlertDirection.below);
    expect(AlertEngine.isMet(up, _quote(price: 106, prev: 100)), isTrue);
    expect(AlertEngine.isMet(up, _quote(price: 104, prev: 100)), isFalse);
    expect(AlertEngine.isMet(down, _quote(price: 94, prev: 100)), isTrue);
    expect(AlertEngine.isMet(down, _quote(price: 96, prev: 100)), isFalse);
  });

  test('volumen inusual', () {
    final a = _alert(type: AlertType.volumeSpike, target: 2);
    expect(AlertEngine.isMet(a, _quote(vol: 3e6, prevVol: 1e6)), isTrue);
    expect(AlertEngine.isMet(a, _quote(vol: 1.5e6, prevVol: 1e6)), isFalse);
    expect(AlertEngine.isMet(a, _quote()), isFalse, reason: 'sin datos de volumen');
  });

  test('cruce de media: exige venir del otro lado', () {
    final a = _alert(type: AlertType.smaCross, target: 50);
    // Ayer 98 bajo la media 100, hoy 101 sobre la media → cruce.
    expect(AlertEngine.isMet(a, _quote(price: 101, prev: 98), sma: 100), isTrue);
    // Ya estaba sobre la media ayer → no es cruce.
    expect(AlertEngine.isMet(a, _quote(price: 105, prev: 102), sma: 100), isFalse);
    expect(AlertEngine.isMet(a, _quote(price: 101, prev: 98)), isFalse, reason: 'sin media');
  });

  group('repetición', () {
    final now = DateTime(2026, 3, 10, 12);

    test('una alerta de un solo uso no vuelve a sonar', () {
      final a = _alert(triggered: true, triggeredAt: DateTime(2026, 3, 1));
      expect(AlertEngine.canFire(a, now), isFalse);
    });

    test('una repetible suena máximo una vez al día', () {
      final today = _alert(repeating: true, triggered: true, triggeredAt: DateTime(2026, 3, 10, 9));
      final yesterday = _alert(repeating: true, triggered: true, triggeredAt: DateTime(2026, 3, 9, 15));
      expect(AlertEngine.canFire(today, now), isFalse);
      expect(AlertEngine.canFire(yesterday, now), isTrue);
    });

    test('evaluate marca la alerta como cumplida y arma el mensaje', () {
      final hits = AlertEngine.evaluate([_alert()], {'AAPL': _quote(price: 120)}, now: now);
      expect(hits, hasLength(1));
      expect(hits.first.updated.triggered, isTrue);
      expect(hits.first.updated.triggeredAt, now);
      expect(hits.first.message, contains('AAPL subió'));
    });
  });
}
