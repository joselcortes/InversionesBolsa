import '../models/account_activity.dart';

/// Venta cerrada con su ganancia/pérdida (costo por método FIFO).
class RealizedSale {
  final DateTime date;
  final String symbol;
  final double qty;
  final double proceedsUsd;
  final double costUsd;
  final double? proceedsClp;
  final double? costClp;

  const RealizedSale({
    required this.date,
    required this.symbol,
    required this.qty,
    required this.proceedsUsd,
    required this.costUsd,
    this.proceedsClp,
    this.costClp,
  });

  double get gainUsd => proceedsUsd - costUsd;
  double? get gainClp =>
      (proceedsClp == null || costClp == null) ? null : proceedsClp! - costClp!;
}

class DividendEntry {
  final DateTime date;
  final String symbol;
  final double grossUsd;
  final double withheldUsd;
  final double? fx;

  const DividendEntry({
    required this.date,
    required this.symbol,
    required this.grossUsd,
    required this.withheldUsd,
    this.fx,
  });

  double? get grossClp => fx == null ? null : grossUsd * fx!;
  double? get withheldClp => fx == null ? null : withheldUsd * fx!;
}

class TaxReport {
  final int year;
  final List<RealizedSale> sales;
  final List<DividendEntry> dividends;

  /// true si faltó el tipo de cambio para alguna fecha (los totales en CLP
  /// quedan incompletos).
  final bool missingFx;

  const TaxReport({
    required this.year,
    required this.sales,
    required this.dividends,
    required this.missingFx,
  });

  double get totalGainUsd => sales.fold(0, (a, s) => a + s.gainUsd);
  double get totalGainClp => sales.fold(0, (a, s) => a + (s.gainClp ?? 0));
  double get totalDividendsUsd => dividends.fold(0, (a, d) => a + d.grossUsd);
  double get totalDividendsClp => dividends.fold(0, (a, d) => a + (d.grossClp ?? 0));
  double get totalWithheldUsd => dividends.fold(0, (a, d) => a + d.withheldUsd);
  double get totalWithheldClp => dividends.fold(0, (a, d) => a + (d.withheldClp ?? 0));

  String toCsv() {
    String n(double? v, [int dec = 2]) => v == null ? '' : v.toStringAsFixed(dec);
    String d(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final b = StringBuffer()
      ..writeln('Reporte referencial año $year — Ventas (FIFO)')
      ..writeln('Fecha;Símbolo;Cantidad;Venta US\$;Costo US\$;Resultado US\$;Venta CLP;Costo CLP;Resultado CLP');
    for (final s in sales) {
      b.writeln('${d(s.date)};${s.symbol};${n(s.qty, 6)};${n(s.proceedsUsd)};${n(s.costUsd)};'
          '${n(s.gainUsd)};${n(s.proceedsClp, 0)};${n(s.costClp, 0)};${n(s.gainClp, 0)}');
    }
    b
      ..writeln('TOTAL;;;;;${n(totalGainUsd)};;;${n(totalGainClp, 0)}')
      ..writeln()
      ..writeln('Dividendos')
      ..writeln('Fecha;Símbolo;Bruto US\$;Retenido EE.UU. US\$;Dólar observado;Bruto CLP;Retenido CLP');
    for (final x in dividends) {
      b.writeln('${d(x.date)};${x.symbol};${n(x.grossUsd)};${n(x.withheldUsd)};'
          '${n(x.fx)};${n(x.grossClp, 0)};${n(x.withheldClp, 0)}');
    }
    b
      ..writeln('TOTAL;;${n(totalDividendsUsd)};${n(totalWithheldUsd)};;'
          '${n(totalDividendsClp, 0)};${n(totalWithheldClp, 0)}')
      ..writeln()
      ..writeln('Cálculo referencial. Revisa con un contador antes de declarar en el SII.');
    return b.toString();
  }
}

class _Lot {
  double qty;
  final double price;
  final double? fx;
  _Lot(this.qty, this.price, this.fx);
}

class TaxCalculator {
  /// [activities] debe incluir TODAS las compras históricas (para conocer el
  /// costo de lo vendido en [year]), no solo las del año.
  /// [fxOn] devuelve el dólar observado de una fecha (o null si no lo hay).
  static TaxReport build({
    required int year,
    required List<AccountActivity> activities,
    required double? Function(DateTime date) fxOn,
  }) {
    final sorted = [...activities]..sort((a, b) => a.date.compareTo(b.date));
    final lots = <String, List<_Lot>>{};
    final sales = <RealizedSale>[];
    var missingFx = false;

    for (final a in sorted.where((a) => a.isFill && a.symbol != null)) {
      final qty = a.qty ?? 0;
      final price = a.price ?? 0;
      if (qty <= 0) continue;
      final fx = fxOn(a.date);
      final queue = lots.putIfAbsent(a.symbol!, () => []);
      if (a.side == 'buy') {
        queue.add(_Lot(qty, price, fx));
        continue;
      }
      // Venta: consumir lotes más antiguos primero (FIFO).
      var remaining = qty;
      var costUsd = 0.0;
      double? costClp = 0.0;
      while (remaining > 1e-9 && queue.isNotEmpty) {
        final lot = queue.first;
        final used = remaining < lot.qty ? remaining : lot.qty;
        costUsd += used * lot.price;
        if (lot.fx == null || costClp == null) {
          costClp = null;
        } else {
          costClp += used * lot.price * lot.fx!;
        }
        lot.qty -= used;
        remaining -= used;
        if (lot.qty <= 1e-9) queue.removeAt(0);
      }
      if (a.date.year != year) continue;
      final proceeds = qty * price;
      if (fx == null || costClp == null) missingFx = true;
      sales.add(RealizedSale(
        date: a.date,
        symbol: a.symbol!,
        qty: qty,
        proceedsUsd: proceeds,
        costUsd: costUsd,
        proceedsClp: fx == null ? null : proceeds * fx,
        costClp: costClp,
      ));
    }

    // Dividendos del año, emparejando la retención del mismo símbolo y día.
    final yearActs = sorted.where((a) => a.date.year == year).toList();
    final dividends = <DividendEntry>[];
    for (final div in yearActs.where((a) => a.isDividend)) {
      final withheld = yearActs
          .where((w) =>
              w.isWithholding &&
              w.symbol == div.symbol &&
              w.date.difference(div.date).inDays.abs() <= 3)
          .fold<double>(0, (s, w) => s + (w.netAmount ?? 0).abs());
      final fx = fxOn(div.date);
      if (fx == null) missingFx = true;
      dividends.add(DividendEntry(
        date: div.date,
        symbol: div.symbol ?? '-',
        grossUsd: div.netAmount ?? 0,
        withheldUsd: withheld,
        fx: fx,
      ));
    }

    return TaxReport(year: year, sales: sales, dividends: dividends, missingFx: missingFx);
  }
}
