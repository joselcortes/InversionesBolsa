import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_agent.dart';
import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';

/// Datos de los agentes publicados junto con la web por `tool/publicar.dart`
/// (carteras simuladas, últimos reportes y resumen del mercado).
class AgentsData {
  final String? updated;
  final Map<String, dynamic> portfolios;
  final Map<String, String> reports;
  final List<dynamic> market;

  const AgentsData({this.updated, this.portfolios = const {}, this.reports = const {}, this.market = const []});

  static const url = 'https://inversiones-cl-34686.web.app/agentes/datos.json';

  static AgentsData? _cache;
  static DateTime? _cachedAt;

  static Future<AgentsData?> fetch({http.Client? client}) async {
    if (_cache != null && _cachedAt != null && DateTime.now().difference(_cachedAt!).inMinutes < 30) {
      return _cache;
    }
    try {
      final res = await (client ?? http.Client())
          .get(Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return _cache;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _cache = AgentsData(
        updated: j['actualizado'] as String?,
        portfolios: (j['carteras'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
        reports: (j['reportes'] as Map?)?.map((k, v) => MapEntry(k as String, v.toString())) ?? const <String, String>{},
        market: (j['mercado'] as List?) ?? const [],
      );
      _cachedAt = DateTime.now();
      return _cache;
    } catch (_) {
      return _cache;
    }
  }
}

/// Convierte los datos en texto para el agente. Se envía lo justo para
/// opinar (sin claves ni identificadores de la cuenta).
class AiContextBuilder {
  static String build({
    required AiAgent agent,
    required PortfolioProvider provider,
    AgentsData? agents,
  }) {
    final b = StringBuffer();

    // --- Cuenta del usuario (Alpaca)
    b.writeln('## Mi cartera (cuenta Alpaca ${provider.isConfigured ? (provider.isLive ? "REAL" : "de práctica/paper") : "no conectada"})');
    final acc = provider.account;
    if (!provider.isConfigured || acc == null) {
      b.writeln('Sin datos: el usuario no ha conectado su cuenta o aún no carga.');
    } else {
      b.writeln('- Patrimonio: ${Fmt.usd(acc.equity)} (hoy ${Fmt.usdSigned(acc.dayChange)}, ${Fmt.pct(acc.dayChangePercent)})');
      b.writeln('- Efectivo: ${Fmt.usd(acc.cash)} · Poder de compra: ${Fmt.usd(acc.buyingPower)}');
      if (provider.usdClp != null) b.writeln('- Dólar observado: ${Fmt.clp(provider.usdClp!)}');
      final clock = provider.clock;
      if (clock != null) b.writeln('- Mercado EE.UU.: ${clock.isOpen ? "abierto" : "cerrado"}');
      if (provider.positions.isEmpty) {
        b.writeln('- Sin posiciones abiertas.');
      } else {
        final total = provider.totalMarketValue;
        b.writeln('- Posiciones (símbolo | cantidad | precio prom. | precio actual | valor | % cartera | ganancia no realizada | hoy):');
        for (final p in provider.positions) {
          final weight = total == 0 ? 0.0 : p.marketValue / total * 100;
          b.writeln('  - ${p.symbol} | ${Fmt.qty(p.qty)} | ${Fmt.usd(p.avgEntryPrice)} | ${Fmt.usd(p.currentPrice)} | '
              '${Fmt.usd(p.marketValue)} | ${Fmt.number(weight)} % | ${Fmt.usdSigned(p.unrealizedPl)} '
              '(${Fmt.pct(p.unrealizedPlPercent)}) | ${Fmt.pct(p.changeTodayPercent)}');
        }
        b.writeln('- Ganancia no realizada total: ${Fmt.usdSigned(provider.totalUnrealizedPl)}');
      }
      final open = provider.openOrders;
      if (open.isNotEmpty) b.writeln('- Órdenes abiertas: ${open.length}');
      if (provider.watchlist.isNotEmpty) {
        final wl = provider.watchlist.take(15).map((s) {
          final q = provider.quotes[s];
          return q == null ? s : '$s ${Fmt.usd(q.price)}';
        }).join(', ');
        b.writeln('- Lista de seguimiento: $wl');
      }
    }

    // --- Carteras y reportes de los agentes
    if (agents == null) {
      b.writeln('\n## Carteras de los agentes\nNo se pudieron descargar (sin conexión o aún no publicadas).');
      return b.toString();
    }
    final ids = agent.portfolioId != null ? [agent.portfolioId!] : agents.portfolios.keys.toList();
    for (final id in ids) {
      final c = agents.portfolios[id];
      if (c == null) continue;
      b.writeln('\n## Cartera simulada "$id" (JSON)');
      b.writeln(_compactPortfolio(c));
      final r = agents.reports[id];
      if (r != null && r.isNotEmpty) {
        b.writeln('\n## Último reporte de "$id"');
        b.writeln(r.length > 5000 ? '${r.substring(0, 5000)}…' : r);
      }
    }
    if (agents.market.isNotEmpty) {
      b.writeln('\n## Resumen de mercado (${agents.updated ?? "sin fecha"}) — indicadores por símbolo (JSON)');
      b.writeln(jsonEncode(agents.market.map(_roundNumbers).toList()));
    }
    return b.toString();
  }

  /// Carteras sin el detalle más largo, para ahorrar cuota.
  static String _compactPortfolio(dynamic c) {
    if (c is! Map) return jsonEncode(c);
    final m = Map<String, dynamic>.from(c);
    final ops = m['operaciones'];
    if (ops is List && ops.length > 10) m['operaciones'] = ops.sublist(ops.length - 10);
    final hist = m['historial_valor'];
    if (hist is List && hist.length > 30) m['historial_valor'] = hist.sublist(hist.length - 30);
    return jsonEncode(_roundNumbers(m));
  }

  static dynamic _roundNumbers(dynamic v) {
    if (v is double) return double.parse(v.toStringAsFixed(2));
    if (v is Map) return v.map((k, e) => MapEntry(k, _roundNumbers(e)));
    if (v is List) return v.map(_roundNumbers).toList();
    return v;
  }
}
