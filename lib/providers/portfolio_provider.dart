import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../models/account_info.dart';
import '../models/asset_info.dart';
import '../models/dca_plan.dart';
import '../models/market_clock.dart';
import '../models/news_item.dart';
import '../models/order_info.dart';
import '../models/position.dart';
import '../models/price_alert.dart';
import '../models/quote.dart';
import '../services/alpaca_service.dart';
import '../services/alpaca_stream_service.dart';
import '../services/asset_cache_service.dart';
import '../services/automation_runner.dart';
import '../services/background_service.dart';
import '../services/credentials_service.dart';
import '../services/fx_service.dart';
import '../services/home_widget_service.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';

const defaultWatchlist = [
  'AAPL',
  'TSLA',
  'NVDA',
  'MSFT',
  'AMZN',
  'GOOGL',
];

class PortfolioProvider extends ChangeNotifier with WidgetsBindingObserver {
  PortfolioProvider({
    CredentialsService? credentialsService,
    LocalStore? store,
    NotificationService? notifications,
  })  : _credentialsService = credentialsService ?? CredentialsService(),
        _store = store ?? LocalStore(),
        _notifications = notifications ?? NotificationService();

  final CredentialsService _credentialsService;
  final LocalStore _store;
  final NotificationService _notifications;
  final FxService _fx = FxService();
  final AssetCacheService _assets = AssetCacheService();
  AlpacaService? _service;
  AlpacaStreamService? _stream;
  AutomationRunner? _runner;

  AlpacaCredentials? credentials;
  AppSettings settings = const AppSettings();
  List<String> watchlist = List.of(defaultWatchlist);
  List<PriceAlert> alerts = [];
  List<DcaPlan> dcaPlans = [];

  AccountInfo? account;
  List<Position> positions = [];
  Map<String, Quote> quotes = {};
  List<NewsItem> news = [];

  /// Noticias solo de tu lista y tus posiciones.
  List<NewsItem> myNews = [];
  List<OrderInfo> orders = [];
  MarketClock? clock;
  double? usdClp;
  Map<String, double> _smas = {};
  String? _smasDay;

  bool initialized = false;
  bool loading = false;
  bool streamConnected = false;
  String? error;
  DateTime? lastUpdated;

  Timer? _quoteTimer;
  Timer? _fullTimer;
  Timer? _notifyThrottle;
  Timer? _tradeRefreshDebounce;
  DateTime _lastStreamAlertCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _inForeground = true;
  bool _checkingAlerts = false;

  bool get isConfigured => credentials != null;
  bool get isLive => credentials?.isLive ?? false;
  bool get hideBalances => settings.hideBalances;

  /// Órdenes vivas, incluyendo las "patas" de un bracket/OCO (el stop-loss y
  /// take-profit quedan anidados en la orden padre ya ejecutada).
  List<OrderInfo> get openOrders => [
        for (final o in orders) ...[
          if (o.isOpen) o,
          ...o.legs.where((l) => l.isOpen),
        ],
      ];

  // ------------------------------------------------------------- Formatos

  String money(double v) => Fmt.usd(v, hidden: hideBalances);
  String moneySigned(double v) => Fmt.usdSigned(v, hidden: hideBalances);

  /// true si los saldos se muestran primero en pesos.
  bool get showsClpFirst =>
      settings.preferClp && settings.showClp && usdClp != null;

  /// Monto en la moneda principal elegida (pesos o dólares).
  String main(double usd) => showsClpFirst
      ? Fmt.clp(usd * usdClp!, hidden: hideBalances)
      : Fmt.usd(usd, hidden: hideBalances);

  /// Igual que [main] pero con signo +/−.
  String mainSigned(double usd) {
    if (!showsClpFirst) return Fmt.usdSigned(usd, hidden: hideBalances);
    if (hideBalances) return Fmt.hiddenMask;
    final v = usd * usdClp!;
    return '${v >= 0 ? "+" : "−"}${Fmt.clp(v.abs())}';
  }

  /// El mismo monto en la otra moneda, como dato secundario
  /// ("US$123,45" o "≈ $115.000 CLP"). null si no aplica.
  String? secondary(double usd, {bool signed = false}) {
    if (showsClpFirst) {
      return signed ? Fmt.usdSigned(usd, hidden: hideBalances) : Fmt.usd(usd, hidden: hideBalances);
    }
    return clp(usd);
  }

  /// "≈ $1.234.567 CLP" o null si está desactivado o no hay tipo de cambio.
  String? clp(double usd) {
    if (!settings.showClp || usdClp == null) return null;
    return '≈ ${Fmt.clp(usd * usdClp!, hidden: hideBalances)} CLP';
  }

  double get totalUnrealizedPl => positions.fold(0, (a, p) => a + p.unrealizedPl);
  double get totalCostBasis => positions.fold(0, (a, p) => a + p.costBasis);
  double get totalMarketValue => positions.fold(0, (a, p) => a + p.marketValue);

  Position? positionFor(String symbol) {
    for (final p in positions) {
      if (p.symbol == symbol) return p;
    }
    return null;
  }

  AssetInfo? assetInfo(String symbol) => _assets.get(symbol);

  // --------------------------------------------------------------- Inicio

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      await _notifications.init();
    } catch (_) {
      // Las notificaciones son una mejora, no algo crítico.
    }
    try {
      settings = await _store.loadSettings();
      alerts = await _store.loadAlerts();
      dcaPlans = await _store.loadDcaPlans();
      watchlist = await _store.loadWatchlist() ?? List.of(defaultWatchlist);
      credentials = await _credentialsService.load();
    } catch (_) {
      // Sin almacenamiento (p. ej. en tests) la app arranca vacía.
    }
    initialized = true;
    notifyListeners();
    if (credentials != null) {
      await _connect(credentials!);
    }
  }

  Future<void> _connect(AlpacaCredentials creds) async {
    final service = AlpacaService(creds);
    _service = service;
    _runner = AutomationRunner(service: service, store: _store, notifications: _notifications);
    await refreshAll();
    _startStream();
    _startTimers();
    unawaited(_syncBackground());
    unawaited(_loadFx());
    unawaited(_assets.ensureLoaded(service).then((_) => notifyListeners()));
  }

  Future<void> _loadFx() async {
    try {
      usdClp = await _fx.latest();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLive();
    super.dispose();
  }

  // -------------------------------------------------- Ciclo de vida / vivo

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isConfigured) return;
    if (state == AppLifecycleState.resumed && !_inForeground) {
      _inForeground = true;
      refreshAll();
      _startStream();
      _startTimers();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_inForeground) {
        _inForeground = false;
        // En segundo plano se apaga el tiempo real para no gastar batería;
        // la tarea de Workmanager toma el relevo.
        _stopLive();
      }
    }
  }

  void _startTimers() {
    _quoteTimer?.cancel();
    _fullTimer?.cancel();
    // Con WebSocket conectado los precios llegan solos; igual refrescamos
    // cada tanto para traer volumen, máximos/mínimos y bid/ask.
    _quoteTimer = Timer.periodic(const Duration(seconds: 15), (t) {
      if (!streamConnected || t.tick % 4 == 0) refreshQuotes();
    });
    _fullTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshAccountData());
  }

  void _stopLive() {
    _quoteTimer?.cancel();
    _fullTimer?.cancel();
    _notifyThrottle?.cancel();
    _tradeRefreshDebounce?.cancel();
    _stream?.stop();
    _stream = null;
    streamConnected = false;
  }

  void _startStream() {
    final creds = credentials;
    if (creds == null) return;
    _stream?.stop();
    _stream = AlpacaStreamService(
      credentials: creds,
      onTrade: _onStreamTrade,
      onTradeUpdate: _onTradeUpdate,
      onStatus: (c) {
        streamConnected = c;
        notifyListeners();
      },
    )..start(_streamSymbols());
  }

  List<String> _streamSymbols() => [
        ...watchlist,
        ...positions.map((p) => p.symbol).where((s) => !watchlist.contains(s)),
      ];

  void _onStreamTrade(String symbol, double price) {
    final q = quotes[symbol];
    if (q == null) return;
    quotes[symbol] = q.withPrice(price);
    // Agrupamos notificaciones de UI (pueden llegar decenas por segundo).
    _notifyThrottle ??= Timer(const Duration(milliseconds: 700), () {
      _notifyThrottle = null;
      notifyListeners();
    });
    final now = DateTime.now();
    if (now.difference(_lastStreamAlertCheck).inSeconds >= 5) {
      _lastStreamAlertCheck = now;
      _checkAlerts();
    }
  }

  void _onTradeUpdate(TradeUpdate u) {
    if (settings.orderNotifications) {
      _runner?.notifyOrder(u.order, event: u.event);
    }
    _tradeRefreshDebounce?.cancel();
    _tradeRefreshDebounce = Timer(const Duration(seconds: 2), _refreshAccountData);
  }

  // ------------------------------------------------------------- Ajustes

  Future<void> updateSettings(AppSettings s) async {
    settings = s;
    notifyListeners();
    await _store.saveSettings(s);
    await _syncBackground();
    if (account != null) _updateWidget();
  }

  Future<void> toggleHideBalances() =>
      updateSettings(settings.copyWith(hideBalances: !settings.hideBalances));

  bool get _needsBackground =>
      isConfigured &&
      (settings.backgroundChecks ||
          settings.dailySummary ||
          settings.orderNotifications ||
          dcaPlans.any((p) => p.enabled));

  Future<void> _syncBackground() async {
    try {
      if (_needsBackground) {
        await BackgroundService.schedule();
      } else {
        await BackgroundService.cancel();
      }
    } catch (_) {}
  }

  // ----------------------------------------------------------- Watchlist

  Future<List<AssetInfo>> searchAssets(String query) async {
    final service = _service;
    if (service == null) return [];
    await _assets.ensureLoaded(service);
    return _assets.search(query);
  }

  /// null si se agregó; si no, el motivo.
  Future<String?> addToWatchlist(String symbol) async {
    final s = symbol.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9.]{1,10}$').hasMatch(s)) {
      return 'Símbolo inválido (usa solo letras, ej: AAPL)';
    }
    if (watchlist.contains(s)) return null;
    final service = _service;
    if (service != null && _assets.get(s) == null) {
      try {
        final asset = await service.getAsset(s);
        if (asset == null) return 'No existe una acción con el símbolo $s';
        if (!asset.tradable) return '$s no se puede operar en Alpaca';
      } catch (_) {
        // Sin red: dejamos agregarlo igual.
      }
    }
    watchlist.add(s);
    await _persistWatchlist();
    await refreshQuotes();
    return null;
  }

  /// Devuelve la posición que tenía (para "Deshacer").
  Future<int> removeFromWatchlist(String symbol) async {
    final index = watchlist.indexOf(symbol);
    watchlist.remove(symbol);
    await _persistWatchlist();
    return index;
  }

  Future<void> insertInWatchlist(int index, String symbol) async {
    if (watchlist.contains(symbol)) return;
    watchlist.insert(index.clamp(0, watchlist.length), symbol);
    await _persistWatchlist();
  }

  /// [newIndex] ya viene ajustado por `onReorderItem`.
  Future<void> reorderWatchlist(int oldIndex, int newIndex) async {
    final s = watchlist.removeAt(oldIndex);
    watchlist.insert(newIndex, s);
    await _persistWatchlist();
  }

  Future<void> _persistWatchlist() async {
    notifyListeners();
    _stream?.updateSymbols(_streamSymbols());
    await _store.saveWatchlist(watchlist);
  }

  // -------------------------------------------------------------- Alertas

  Future<void> addAlert({
    required String symbol,
    required AlertType type,
    required AlertDirection direction,
    required double target,
    required bool repeating,
  }) async {
    alerts = await _store.loadAlerts();
    alerts.add(PriceAlert(
      id: const Uuid().v4(),
      symbol: symbol.trim().toUpperCase(),
      type: type,
      direction: direction,
      target: target,
      repeating: repeating,
      createdAt: DateTime.now(),
    ));
    await _store.saveAlerts(alerts);
    _smasDay = null;
    notifyListeners();
    await refreshQuotes();
  }

  Future<void> removeAlert(String id) async {
    alerts = await _store.loadAlerts();
    alerts.removeWhere((a) => a.id == id);
    await _store.saveAlerts(alerts);
    notifyListeners();
  }

  /// Reactiva una alerta de un solo uso ya cumplida.
  Future<void> rearmAlert(String id) async {
    alerts = await _store.loadAlerts();
    alerts = alerts
        .map((a) => a.id == id
            ? PriceAlert(
                id: a.id,
                symbol: a.symbol,
                type: a.type,
                direction: a.direction,
                target: a.target,
                repeating: a.repeating,
                createdAt: a.createdAt,
              )
            : a)
        .toList();
    await _store.saveAlerts(alerts);
    notifyListeners();
  }

  Future<void> _checkAlerts() async {
    final runner = _runner;
    if (runner == null || _checkingAlerts) return;
    _checkingAlerts = true;
    try {
      // Medias móviles para alertas de cruce: se recalculan una vez al día.
      final today = AutomationRunner.dayKey(DateTime.now());
      if (_smasDay != today && alerts.any((a) => a.type == AlertType.smaCross)) {
        _smas = await runner.smasFor(alerts);
        _smasDay = today;
      }
      alerts = await runner.checkAlerts(quotes: quotes, smas: _smas);
    } catch (_) {
    } finally {
      _checkingAlerts = false;
    }
  }

  // ------------------------------------------------------ Compras (DCA)

  Future<void> addDcaPlan({
    required String symbol,
    required double amountUsd,
    required DcaFrequency frequency,
    required int day,
    required bool startThisPeriod,
  }) async {
    dcaPlans = await _store.loadDcaPlans();
    final plan = DcaPlan(
      id: const Uuid().v4().replaceAll('-', ''),
      symbol: symbol.trim().toUpperCase(),
      amountUsd: amountUsd,
      frequency: frequency,
      day: day,
      enabled: true,
      createdAt: DateTime.now(),
    );
    // Si no se pidió partir ya, se marca el periodo actual como hecho para
    // que la primera compra sea en el próximo.
    final now = clock?.nyNow ?? DateTime.now();
    dcaPlans.add(startThisPeriod ? plan : plan.copyWith(lastRunKey: plan.periodKey(now)));
    await _store.saveDcaPlans(dcaPlans);
    notifyListeners();
    await _syncBackground();
  }

  Future<void> setDcaEnabled(String id, bool enabled) async {
    dcaPlans = await _store.loadDcaPlans();
    dcaPlans = dcaPlans.map((p) => p.id == id ? p.copyWith(enabled: enabled) : p).toList();
    await _store.saveDcaPlans(dcaPlans);
    notifyListeners();
    await _syncBackground();
  }

  Future<void> removeDcaPlan(String id) async {
    dcaPlans = await _store.loadDcaPlans();
    dcaPlans.removeWhere((p) => p.id == id);
    await _store.saveDcaPlans(dcaPlans);
    notifyListeners();
    await _syncBackground();
  }

  // -------------------------------------------------------------- Órdenes

  Future<void> cancelOrder(String id) async {
    await requireService().cancelOrder(id);
    await _refreshAccountData();
  }

  // ------------------------------------------------------------ Cuenta

  Future<bool> saveCredentials({
    required String keyId,
    required String secretKey,
    required bool isLive,
  }) async {
    final creds = AlpacaCredentials(
      keyId: keyId.trim(),
      secretKey: secretKey.trim(),
      isLive: isLive,
    );
    final ok = await AlpacaService(creds).testConnection();
    if (!ok) return false;

    await _credentialsService.save(
      keyId: creds.keyId,
      secretKey: creds.secretKey,
      isLive: isLive,
    );
    _stopLive();
    credentials = creds;
    await _connect(creds);
    return true;
  }

  Future<void> logout() async {
    _stopLive();
    await _credentialsService.clear();
    credentials = null;
    _service = null;
    _runner = null;
    account = null;
    positions = [];
    quotes = {};
    news = [];
    myNews = [];
    orders = [];
    clock = null;
    await BackgroundService.cancel().catchError((_) {});
    notifyListeners();
  }

  // ------------------------------------------------------------- Refresco

  Future<void> refreshAll() async {
    final service = _service;
    if (service == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        service.getAccount(),
        service.getPositions(),
        service.getNews(limit: 30),
        service.getOrders(limit: 40),
        service.getClock(),
      ]);
      account = results[0] as AccountInfo;
      positions = results[1] as List<Position>;
      news = results[2] as List<NewsItem>;
      orders = results[3] as List<OrderInfo>;
      clock = results[4] as MarketClock;
      quotes = await service.getSnapshots(_allSymbols());
      lastUpdated = DateTime.now();
      _stream?.updateSymbols(_streamSymbols());
      try {
        myNews = await service.getNews(symbols: _streamSymbols(), limit: 40);
      } catch (_) {}
      await _checkAlerts();
      await _runForegroundAutomation();
      _updateWidget();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _refreshAccountData() async {
    final service = _service;
    if (service == null) return;
    try {
      final results = await Future.wait([
        service.getAccount(),
        service.getPositions(),
        service.getOrders(limit: 40),
        service.getClock(),
      ]);
      account = results[0] as AccountInfo;
      positions = results[1] as List<Position>;
      orders = results[2] as List<OrderInfo>;
      clock = results[3] as MarketClock;
      error = null;
      lastUpdated = DateTime.now();
      _updateWidget();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// Compras periódicas y resumen diario también corren con la app abierta
  /// (útil en plataformas sin tarea en segundo plano). El client_order_id
  /// evita compras duplicadas si ambos corren a la vez.
  Future<void> _runForegroundAutomation() async {
    final runner = _runner;
    final c = clock;
    if (runner == null || c == null) return;
    try {
      await runner.runDcaPlans(c);
      dcaPlans = await _store.loadDcaPlans();
      if (settings.dailySummary) await runner.maybeDailySummary(c);
    } catch (_) {}
  }

  void _updateWidget() {
    final a = account;
    if (a == null) return;
    HomeWidgetService.update(
      value: a.equity,
      dayChange: a.dayChange,
      dayChangePercent: a.dayChangePercent,
      hidden: hideBalances,
      isLive: isLive,
      usdClp: showsClpFirst ? usdClp : null,
    );
  }

  Future<void> refreshQuotes() async {
    final service = _service;
    if (service == null) return;
    try {
      quotes = await service.getSnapshots(_allSymbols());
      lastUpdated = DateTime.now();
      await _checkAlerts();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  List<String> _allSymbols() {
    final set = <String>{
      ...watchlist,
      ...positions.map((p) => p.symbol),
      ...alerts.where((a) => a.isActive).map((a) => a.symbol),
      ...dcaPlans.map((p) => p.symbol),
    };
    return set.toList();
  }

  AlpacaService requireService() {
    final service = _service;
    if (service == null) {
      throw AlpacaException('Configura tus API keys en Ajustes primero');
    }
    return service;
  }
}
