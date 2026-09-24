import 'package:intl/intl.dart';

/// Formatos de números al estilo chileno: punto para miles y coma para
/// decimales.
class Fmt {
  static const hiddenMask = '••••••';

  static final _usd = NumberFormat.currency(locale: 'es_CL', symbol: 'US\$', decimalDigits: 2);
  static final _clp = NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
  static final _num2 = NumberFormat.decimalPatternDigits(locale: 'es_CL', decimalDigits: 2);
  static final _qty = NumberFormat('#,##0.######', 'es_CL');
  static final _compact = NumberFormat.compact(locale: 'es');

  static String usd(double v, {bool hidden = false}) => hidden ? hiddenMask : _usd.format(v);

  /// Monto US$ con signo explícito (+/−), útil para variaciones.
  static String usdSigned(double v, {bool hidden = false}) =>
      hidden ? hiddenMask : '${v >= 0 ? "+" : "−"}${_usd.format(v.abs())}';

  static String clp(double v, {bool hidden = false}) => hidden ? hiddenMask : _clp.format(v);

  static String pct(double v, {bool signed = true}) =>
      '${signed && v >= 0 ? "+" : ""}${_num2.format(v)}%';

  static String number(double v) => _num2.format(v);

  static String qty(double v) => _qty.format(v);

  static String compact(double v) => _compact.format(v);

  /// Nombre de empresa corto: "Apple Inc. Common Stock" → "Apple".
  static String shortName(String name) {
    var s = name
        .replaceAll(RegExp(r'\s+(Common Stock|Ordinary Shares|American Depositary Shares?|Class [A-Z]\b).*$',
            caseSensitive: false), '')
        .replaceAll(RegExp(r',?\s+(Inc\.?|Corp\.?|Corporation|Incorporated|Ltd\.?|PLC|N\.V\.|S\.A\.|Co\.)$',
            caseSensitive: false), '')
        .trim();
    if (s.isEmpty) s = name;
    return s;
  }

  /// Acepta "1.234,56", "1234.56" o "1234,56".
  static double? parse(String raw) {
    var s = raw.trim().replaceAll(' ', '').replaceAll('US\$', '').replaceAll('\$', '');
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      // El último separador es el decimal.
      if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else {
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s);
  }
}
