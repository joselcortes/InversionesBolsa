import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/order_info.dart';
import 'credentials_service.dart';

/// Evento de una orden propia (ejecutada, cancelada, rechazada…).
class TradeUpdate {
  final String event;
  final OrderInfo order;
  const TradeUpdate(this.event, this.order);
}

/// Conexiones WebSocket a Alpaca mientras la app está abierta:
/// - precios en tiempo real (feed IEX gratuito, máx. 30 símbolos),
/// - actualizaciones de tus órdenes (`trade_updates`).
/// Se reconecta sola con espera creciente si se corta.
class AlpacaStreamService {
  final AlpacaCredentials credentials;
  final void Function(String symbol, double price) onTrade;
  final void Function(TradeUpdate update) onTradeUpdate;
  final void Function(bool connected)? onStatus;

  AlpacaStreamService({
    required this.credentials,
    required this.onTrade,
    required this.onTradeUpdate,
    this.onStatus,
  });

  static const maxSymbols = 30;

  WebSocketChannel? _market;
  WebSocketChannel? _trading;
  StreamSubscription? _marketSub;
  StreamSubscription? _tradingSub;
  Set<String> _subscribed = {};
  Set<String> _wanted = {};
  bool _marketAuthed = false;
  bool _stopped = true;
  int _marketRetries = 0;
  int _tradingRetries = 0;
  Timer? _marketRetryTimer;
  Timer? _tradingRetryTimer;

  bool get isConnected => _marketAuthed;

  String get _tradingUrl => credentials.isLive
      ? 'wss://api.alpaca.markets/stream'
      : 'wss://paper-api.alpaca.markets/stream';

  void start(Iterable<String> symbols) {
    _stopped = false;
    _wanted = symbols.take(maxSymbols).toSet();
    _connectMarket();
    _connectTrading();
  }

  void stop() {
    _stopped = true;
    _marketRetryTimer?.cancel();
    _tradingRetryTimer?.cancel();
    _marketSub?.cancel();
    _tradingSub?.cancel();
    _market?.sink.close();
    _trading?.sink.close();
    _market = null;
    _trading = null;
    _marketAuthed = false;
    _subscribed = {};
    onStatus?.call(false);
  }

  /// Ajusta los símbolos suscritos (watchlist + posiciones + alertas).
  void updateSymbols(Iterable<String> symbols) {
    _wanted = symbols.take(maxSymbols).toSet();
    if (_marketAuthed) _syncSubscriptions();
  }

  void _syncSubscriptions() {
    final toAdd = _wanted.difference(_subscribed).toList();
    final toRemove = _subscribed.difference(_wanted).toList();
    if (toRemove.isNotEmpty) {
      _market?.sink.add(jsonEncode({'action': 'unsubscribe', 'trades': toRemove}));
    }
    if (toAdd.isNotEmpty) {
      _market?.sink.add(jsonEncode({'action': 'subscribe', 'trades': toAdd}));
    }
    _subscribed = {..._wanted};
  }

  void _connectMarket() {
    if (_stopped) return;
    try {
      final ch = WebSocketChannel.connect(
          Uri.parse('wss://stream.data.alpaca.markets/v2/iex'));
      _market = ch;
      _marketSub = ch.stream.listen(
        _onMarketMessage,
        onError: (_) => _scheduleMarketReconnect(),
        onDone: _scheduleMarketReconnect,
        cancelOnError: true,
      );
      ch.sink.add(jsonEncode({
        'action': 'auth',
        'key': credentials.keyId,
        'secret': credentials.secretKey,
      }));
    } catch (_) {
      _scheduleMarketReconnect();
    }
  }

  void _onMarketMessage(dynamic raw) {
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    final decoded = jsonDecode(text);
    if (decoded is! List) return;
    for (final m in decoded) {
      if (m is! Map) continue;
      switch (m['T']) {
        case 'success':
          if (m['msg'] == 'authenticated') {
            _marketAuthed = true;
            _marketRetries = 0;
            _subscribed = {};
            _syncSubscriptions();
            onStatus?.call(true);
          }
        case 't':
          final symbol = m['S'] as String?;
          final price = (m['p'] as num?)?.toDouble();
          if (symbol != null && price != null) onTrade(symbol, price);
        case 'error':
          // 406 = ya hay otra conexión abierta con estas keys (el plan
          // gratuito permite una). No reintentamos en bucle.
          if (m['code'] == 406 || m['code'] == 402) {
            _marketRetries = 10;
          }
      }
    }
  }

  void _scheduleMarketReconnect() {
    _marketAuthed = false;
    onStatus?.call(false);
    if (_stopped) return;
    _marketRetryTimer?.cancel();
    final secs = (2 << _marketRetries.clamp(0, 6)).clamp(2, 120);
    _marketRetries++;
    _marketRetryTimer = Timer(Duration(seconds: secs), _connectMarket);
  }

  void _connectTrading() {
    if (_stopped) return;
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_tradingUrl));
      _trading = ch;
      _tradingSub = ch.stream.listen(
        _onTradingMessage,
        onError: (_) => _scheduleTradingReconnect(),
        onDone: _scheduleTradingReconnect,
        cancelOnError: true,
      );
      ch.sink.add(jsonEncode({
        'action': 'auth',
        'key': credentials.keyId,
        'secret': credentials.secretKey,
      }));
    } catch (_) {
      _scheduleTradingReconnect();
    }
  }

  void _onTradingMessage(dynamic raw) {
    // Este stream manda frames binarios con JSON.
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    final m = jsonDecode(text);
    if (m is! Map) return;
    final stream = m['stream'];
    final data = m['data'];
    if (data is! Map) return;
    if (stream == 'authorization') {
      if (data['status'] == 'authorized') {
        _tradingRetries = 0;
        _trading?.sink.add(jsonEncode({
          'action': 'listen',
          'data': {
            'streams': ['trade_updates'],
          },
        }));
      }
    } else if (stream == 'trade_updates') {
      final order = data['order'];
      if (order is Map<String, dynamic>) {
        onTradeUpdate(TradeUpdate(data['event'] as String? ?? '', OrderInfo.fromJson(order)));
      }
    }
  }

  void _scheduleTradingReconnect() {
    if (_stopped) return;
    _tradingRetryTimer?.cancel();
    final secs = (2 << _tradingRetries.clamp(0, 6)).clamp(2, 120);
    _tradingRetries++;
    _tradingRetryTimer = Timer(Duration(seconds: secs), _connectTrading);
  }
}
