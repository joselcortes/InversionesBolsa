import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/account_activity.dart';
import '../models/account_info.dart';
import '../models/asset_info.dart';
import '../models/chart_range.dart';
import '../models/market_clock.dart';
import '../models/news_item.dart';
import '../models/order_info.dart';
import '../models/portfolio_history.dart';
import '../models/position.dart';
import '../models/price_bar.dart';
import '../models/quote.dart';
import 'credentials_service.dart';

class AlpacaException implements Exception {
  final String message;
  final int? statusCode;
  AlpacaException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Símbolos válidos: letras, números y punto (ej. BRK.B). Cualquier otra
/// entrada se rechaza antes de tocar la red, para no inyectar texto
/// arbitrario en las URLs de la API.
final _validSymbol = RegExp(r'^[A-Z0-9.]{1,10}$');
final _validOrderId = RegExp(r'^[a-f0-9-]{8,64}$');

void assertValidSymbol(String symbol) {
  if (!_validSymbol.hasMatch(symbol)) {
    throw AlpacaException('Símbolo inválido: $symbol');
  }
}

/// Alpaca rechaza precios con más de 2 decimales sobre US$1 (sub-penny).
String formatPrice(double p) => p >= 1 ? p.toStringAsFixed(2) : p.toStringAsFixed(4);

String _formatQty(double q) {
  final s = q.toStringAsFixed(9);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

/// Cliente para la API de Alpaca (trading + datos de mercado + noticias).
/// Usa las credenciales que el propio usuario ingresó en Ajustes; nunca
/// incluye claves de terceros ni las expone en logs.
class AlpacaService {
  final AlpacaCredentials credentials;

  AlpacaService(this.credentials);

  String get _tradingBase => credentials.isLive
      ? 'https://api.alpaca.markets'
      : 'https://paper-api.alpaca.markets';

  static const _dataBase = 'https://data.alpaca.markets';

  static const _timeout = Duration(seconds: 20);

  // Content-Type solo en los POST: la API de datos no lo permite en GET
  // desde un navegador (CORS) y en GET no hace falta.
  Map<String, String> get _headers => {
        'APCA-API-KEY-ID': credentials.keyId,
        'APCA-API-SECRET-KEY': credentials.secretKey,
      };

  Future<http.Response> _get(Uri uri) => _wrapErrors(
        () => http.get(uri, headers: _headers).timeout(_timeout),
      );

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body) =>
      _wrapErrors(
        () => http
            .post(uri,
                headers: {..._headers, 'Content-Type': 'application/json'},
                body: jsonEncode(body))
            .timeout(_timeout),
      );

  Future<http.Response> _delete(Uri uri) => _wrapErrors(
        () => http.delete(uri, headers: _headers).timeout(_timeout),
      );

  Future<http.Response> _wrapErrors(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw AlpacaException('La solicitud tardó demasiado. Revisa tu conexión.');
    } on SocketException {
      throw AlpacaException('Sin conexión a internet.');
    } on http.ClientException {
      throw AlpacaException('Error de red. Intenta de nuevo.');
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Error ${res.statusCode}';
    if (res.statusCode == 401) {
      message = 'API keys inválidas.';
    } else if (res.statusCode == 429) {
      message = 'Demasiadas consultas a Alpaca. Espera unos segundos.';
    } else {
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      if (res.statusCode == 403 && message == 'Error 403') {
        message = 'Sin permiso para esta operación (¿fondos o acciones insuficientes?).';
      }
    }
    throw AlpacaException(message, statusCode: res.statusCode);
  }

  // ---------------------------------------------------------------- Cuenta

  Future<AccountInfo> getAccount() async {
    final res = await _get(Uri.parse('$_tradingBase/v2/account'));
    return AccountInfo.fromJson(_decode(res) as Map<String, dynamic>);
  }

  Future<List<Position>> getPositions() async {
    final res = await _get(Uri.parse('$_tradingBase/v2/positions'));
    final data = _decode(res) as List;
    return data
        .map((e) => Position.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MarketClock> getClock() async {
    final res = await _get(Uri.parse('$_tradingBase/v2/clock'));
    return MarketClock.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// true si [date] (fecha de NY) es día hábil de la bolsa (no feriado).
  Future<bool> isTradingDay(DateTime date) async {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final res = await _get(Uri.parse('$_tradingBase/v2/calendar?start=$d&end=$d'));
    final data = _decode(res) as List;
    return data.isNotEmpty;
  }

  Future<PortfolioHistory> getPortfolioHistory(HistoryRange range) async {
    final res = await _get(Uri.parse('$_tradingBase/v2/account/portfolio/history'
        '?period=${range.period}&timeframe=${range.timeframe}'
        '&intraday_reporting=market_hours'));
    return PortfolioHistory.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Movimientos de la cuenta (compras, ventas, dividendos, retenciones…),
  /// del más reciente al más antiguo. Pagina automáticamente.
  Future<List<AccountActivity>> getActivities({
    List<String>? types,
    DateTime? after,
    int maxPages = 40,
  }) async {
    final out = <AccountActivity>[];
    String? pageToken;
    for (var page = 0; page < maxPages; page++) {
      final params = <String, String>{
        'direction': 'desc',
        'page_size': '100',
        if (types != null && types.isNotEmpty) 'activity_types': types.join(','),
        if (after != null) 'after': after.toUtc().toIso8601String(),
        'page_token': ?pageToken,
      };
      final uri = Uri.parse('$_tradingBase/v2/account/activities')
          .replace(queryParameters: params);
      final data = _decode(await _get(uri)) as List;
      out.addAll(data.map((e) => AccountActivity.fromJson(e as Map<String, dynamic>)));
      if (data.length < 100) break;
      pageToken = (data.last as Map<String, dynamic>)['id'] as String?;
      if (pageToken == null) break;
    }
    return out;
  }

  // ---------------------------------------------------------------- Activos

  /// Todas las acciones de EE.UU. activas (son miles; conviene cachear).
  Future<List<AssetInfo>> getAllAssets() async {
    final res = await _get(Uri.parse(
        '$_tradingBase/v2/assets?status=active&asset_class=us_equity'));
    final data = _decode(res) as List;
    return data
        .map((e) => AssetInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AssetInfo?> getAsset(String symbol) async {
    assertValidSymbol(symbol);
    try {
      final res = await _get(Uri.parse('$_tradingBase/v2/assets/$symbol'));
      return AssetInfo.fromJson(_decode(res) as Map<String, dynamic>);
    } on AlpacaException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 422) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------- Órdenes

  Future<List<OrderInfo>> getOrders({
    String status = 'all',
    int limit = 30,
    DateTime? after,
  }) async {
    final params = <String, String>{
      'status': status,
      'limit': '$limit',
      'direction': 'desc',
      'nested': 'true',
      if (after != null) 'after': after.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$_tradingBase/v2/orders').replace(queryParameters: params);
    final data = _decode(await _get(uri)) as List;
    return data
        .map((e) => OrderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderInfo>> getRecentOrders({int limit = 20}) => getOrders(limit: limit);

  Future<void> cancelOrder(String orderId) async {
    if (!_validOrderId.hasMatch(orderId)) {
      throw AlpacaException('ID de orden inválido');
    }
    _decode(await _delete(Uri.parse('$_tradingBase/v2/orders/$orderId')));
  }

  /// Envía una orden real (o de simulación, según el modo de las
  /// credenciales) a Alpaca. Se espera que la UI ya haya mostrado una
  /// confirmación explícita al usuario antes de llamar esto. Devuelve la
  /// orden tal como la reporta Alpaca (puede quedar "pendiente" si el
  /// mercado está cerrado).
  ///
  /// - [qty] o [notional] (monto en US$), exactamente uno de los dos.
  /// - [type]: market | limit | stop | trailing_stop.
  /// - Compra con [takeProfitPrice] y/o [stopLossPrice]: orden bracket (ambos)
  ///   u OTO (solo uno). Quedan programadas en el bróker, no dependen de que
  ///   la app esté abierta.
  /// - Venta con [takeProfitPrice] y [stopLossPrice]: orden OCO para proteger
  ///   una posición existente (la primera que se cumpla cancela la otra).
  /// - [clientOrderId] sirve para evitar duplicados (Alpaca rechaza un ID
  ///   repetido); lo usan las compras periódicas automáticas.
  Future<OrderInfo> placeOrder({
    required String symbol,
    required String side, // 'buy' | 'sell'
    double? qty,
    double? notional,
    String type = 'market',
    double? limitPrice,
    double? stopPrice,
    double? trailPercent,
    double? takeProfitPrice,
    double? stopLossPrice,
    String? clientOrderId,
  }) async {
    assertValidSymbol(symbol);
    if (side != 'buy' && side != 'sell') {
      throw AlpacaException('Lado de orden inválido');
    }
    if ((qty == null) == (notional == null)) {
      throw AlpacaException('Indica cantidad de acciones o monto, no ambos');
    }
    if (qty != null && qty <= 0) {
      throw AlpacaException('La cantidad debe ser mayor a 0');
    }
    if (notional != null && notional < 1) {
      throw AlpacaException('El monto mínimo es US\$1');
    }
    if (type == 'limit' && limitPrice == null) {
      throw AlpacaException('Falta el precio límite');
    }
    if (type == 'stop' && stopPrice == null) {
      throw AlpacaException('Falta el precio de stop');
    }
    if (type == 'trailing_stop' && (trailPercent == null || trailPercent <= 0)) {
      throw AlpacaException('Falta el % del trailing stop');
    }

    final isFractional = notional != null || (qty != null && qty != qty.roundToDouble());
    final hasTp = takeProfitPrice != null;
    final hasSl = stopLossPrice != null;

    String orderClass = 'simple';
    if (side == 'buy' && (hasTp || hasSl)) {
      // Alpaca exige ambos precios para bracket; con uno solo es OTO.
      orderClass = hasTp && hasSl ? 'bracket' : 'oto';
    } else if (side == 'sell' && hasTp && hasSl) {
      orderClass = 'oco';
      type = 'limit';
    }

    if (isFractional && (orderClass != 'simple' || type == 'trailing_stop' || type == 'stop')) {
      throw AlpacaException(
          'Las órdenes con stop, trailing o SL/TP requieren acciones enteras');
    }

    final isConditional = orderClass != 'simple' || type == 'stop' || type == 'trailing_stop';
    final tif = isFractional
        ? 'day'
        : (isConditional || type == 'limit')
            ? 'gtc'
            : 'day';

    final body = <String, dynamic>{
      'symbol': symbol,
      'side': side,
      'type': type,
      'time_in_force': tif,
      if (qty != null) 'qty': _formatQty(qty),
      if (notional != null) 'notional': notional.toStringAsFixed(2),
      if (type == 'limit' && limitPrice != null && orderClass != 'oco')
        'limit_price': formatPrice(limitPrice),
      if (type == 'stop' && stopPrice != null) 'stop_price': formatPrice(stopPrice),
      if (type == 'trailing_stop') 'trail_percent': trailPercent!.toStringAsFixed(2),
      if (orderClass != 'simple') 'order_class': orderClass,
      if (hasTp && orderClass != 'simple')
        'take_profit': {'limit_price': formatPrice(takeProfitPrice)},
      if (hasSl && orderClass != 'simple')
        'stop_loss': {'stop_price': formatPrice(stopLossPrice)},
      'client_order_id': ?clientOrderId,
    };
    final res = await _post(Uri.parse('$_tradingBase/v2/orders'), body);
    return OrderInfo.fromJson(_decode(res) as Map<String, dynamic>);
  }

  // --------------------------------------------------------- Datos mercado

  Future<Map<String, Quote>> getSnapshots(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    for (final s in symbols) {
      assertValidSymbol(s);
    }
    final result = <String, Quote>{};
    // La API acepta muchas, pero partimos en bloques para URLs razonables.
    for (var i = 0; i < symbols.length; i += 100) {
      final chunk = symbols.sublist(i, i + 100 > symbols.length ? symbols.length : i + 100);
      final res = await _get(Uri.parse(
          '$_dataBase/v2/stocks/snapshots?symbols=${chunk.join(',')}&feed=iex'));
      final data = _decode(res) as Map<String, dynamic>;
      data.forEach((symbol, value) {
        if (value == null) return;
        final q = Quote.fromSnapshot(symbol, value as Map<String, dynamic>);
        if (q != null) result[symbol] = q;
      });
    }
    return result;
  }

  Future<List<PriceBar>> _bars(
    String symbol, {
    required String timeframe,
    required DateTime start,
    int maxPages = 5,
  }) async {
    assertValidSymbol(symbol);
    final out = <PriceBar>[];
    String? pageToken;
    for (var page = 0; page < maxPages; page++) {
      final params = <String, String>{
        'timeframe': timeframe,
        'start': start.toUtc().toIso8601String(),
        'limit': '10000',
        'feed': 'iex',
        'adjustment': 'split',
        'page_token': ?pageToken,
      };
      final uri = Uri.parse('$_dataBase/v2/stocks/$symbol/bars')
          .replace(queryParameters: params);
      final data = _decode(await _get(uri)) as Map<String, dynamic>;
      final bars = (data['bars'] as List?) ?? const [];
      out.addAll(bars.map((e) => PriceBar.fromJson(e as Map<String, dynamic>)));
      pageToken = data['next_page_token'] as String?;
      if (pageToken == null) break;
    }
    return out;
  }

  /// Últimas [limit] velas diarias (aprox.).
  Future<List<PriceBar>> getDailyBars(String symbol, {int limit = 30}) async {
    final start = DateTime.now().subtract(Duration(days: (limit * 1.5).ceil() + 7));
    final bars = await _bars(symbol, timeframe: '1Day', start: start);
    return bars.length > limit ? bars.sublist(bars.length - limit) : bars;
  }

  Future<List<PriceBar>> getBarsForRange(String symbol, ChartRange range) async {
    final bars = await _bars(
      symbol,
      timeframe: range.timeframe,
      start: DateTime.now().subtract(range.lookback),
    );
    if (range == ChartRange.day1 && bars.isNotEmpty) {
      // Solo la última sesión disponible.
      final last = bars.last.time.toUtc();
      return bars.where((b) {
        final t = b.time.toUtc();
        return t.year == last.year && t.month == last.month && t.day == last.day;
      }).toList();
    }
    return bars;
  }

  Future<List<NewsItem>> getNews({List<String>? symbols, int limit = 20}) async {
    if (symbols != null) {
      for (final s in symbols) {
        assertValidSymbol(s);
      }
    }
    final symbolsParam = (symbols != null && symbols.isNotEmpty)
        ? '&symbols=${symbols.join(',')}'
        : '';
    final res = await _get(
        Uri.parse('$_dataBase/v1beta1/news?limit=$limit$symbolsParam'));
    final data = _decode(res) as Map<String, dynamic>;
    final news = (data['news'] as List?) ?? const [];
    return news
        .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> testConnection() async {
    try {
      await getAccount();
      return true;
    } catch (_) {
      return false;
    }
  }
}
