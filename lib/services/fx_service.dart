import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Dólar observado (Banco Central de Chile) vía mindicador.cl, gratis y
/// sin API key. Se cachea localmente.
class FxService {
  static const _latestKey = 'fx_usdclp_latest_v1';
  static const _yearKeyPrefix = 'fx_usdclp_year_v1_';

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Último dólar observado. Usa el caché si tiene menos de 6 horas o si no
  /// hay internet.
  Future<double?> latest() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_latestKey);
    Map<String, dynamic>? cache;
    if (cached != null) {
      cache = jsonDecode(cached) as Map<String, dynamic>;
      final at = DateTime.tryParse(cache['at'] as String? ?? '');
      if (at != null && DateTime.now().difference(at).inHours < 6) {
        return (cache['value'] as num).toDouble();
      }
    }
    try {
      final res = await http
          .get(Uri.parse('https://mindicador.cl/api/dolar'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final serie = (jsonDecode(res.body)['serie'] as List?) ?? const [];
        if (serie.isNotEmpty) {
          final value = (serie.first['valor'] as num).toDouble();
          await prefs.setString(_latestKey, jsonEncode({
            'value': value,
            'at': DateTime.now().toIso8601String(),
          }));
          return value;
        }
      }
    } catch (_) {}
    return cache == null ? null : (cache['value'] as num).toDouble();
  }

  /// Serie diaria del año [year]: fecha (yyyy-mm-dd) → valor.
  Future<Map<String, double>> yearSeries(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final isPastYear = year < DateTime.now().year;
    final cached = prefs.getString('$_yearKeyPrefix$year');
    if (cached != null && isPastYear) {
      return (jsonDecode(cached) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    try {
      final res = await http
          .get(Uri.parse('https://mindicador.cl/api/dolar/$year'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final serie = (jsonDecode(res.body)['serie'] as List?) ?? const [];
        final map = <String, double>{};
        for (final e in serie) {
          final d = DateTime.tryParse(e['fecha'] as String? ?? '');
          if (d == null) continue;
          // mindicador entrega la fecha en UTC (medianoche Chile = 03/04 UTC).
          map[_dateKey(d.toLocal())] = (e['valor'] as num).toDouble();
        }
        await prefs.setString('$_yearKeyPrefix$year', jsonEncode(map));
        return map;
      }
    } catch (_) {}
    if (cached != null) {
      return (jsonDecode(cached) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    return {};
  }

  /// Busca el valor de [date] en [series]; si ese día no hubo publicación
  /// (fin de semana/feriado) usa el día hábil anterior más cercano.
  static double? lookup(Map<String, double> series, DateTime date) {
    for (var i = 0; i < 10; i++) {
      final v = series[_dateKey(date.subtract(Duration(days: i)))];
      if (v != null) return v;
    }
    return null;
  }
}
