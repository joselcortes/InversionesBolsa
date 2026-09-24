import '../models/dca_plan.dart';
import '../models/market_clock.dart';
import '../models/order_info.dart';
import '../models/price_alert.dart';
import '../models/quote.dart';
import '../utils/alert_engine.dart';
import '../utils/formatters.dart';
import '../utils/indicators.dart';
import 'alpaca_service.dart';
import 'fx_service.dart';
import 'home_widget_service.dart';
import 'local_store.dart';
import 'notification_service.dart';

/// Tareas automáticas compartidas entre la app abierta y la tarea en
/// segundo plano (Workmanager, cada ~15 min):
/// alertas, avisos de órdenes, compras periódicas, resumen diario y widget.
class AutomationRunner {
  final AlpacaService service;
  final LocalStore store;
  final NotificationService notifications;

  AutomationRunner({
    required this.service,
    required this.store,
    required this.notifications,
  });

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Ciclo completo que corre la tarea en segundo plano.
  Future<void> runAll() async {
    final settings = await store.loadSettings();
    MarketClock? clock;
    try {
      clock = await service.getClock();
    } catch (_) {}

    Future<void> safe(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {
        // Una tarea que falla (red, límite de la API) no frena las demás.
      }
    }

    if (settings.backgroundChecks) await safe(() => checkAlerts());
    if (settings.orderNotifications) await safe(checkClosedOrders);
    if (clock != null) {
      final c = clock;
      await safe(() => runDcaPlans(c));
      if (settings.dailySummary) await safe(() => maybeDailySummary(c));
    }
    await safe(() => updateHomeWidget(hidden: settings.hideBalances));
  }

  /// Medias móviles que necesitan las alertas de cruce (clave "SIM:N").
  Future<Map<String, double>> smasFor(List<PriceAlert> alerts) async {
    final out = <String, double>{};
    final needed = <String, Set<int>>{};
    for (final a in alerts.where((a) => a.type == AlertType.smaCross && a.isActive)) {
      needed.putIfAbsent(a.symbol, () => {}).add(a.target.toInt());
    }
    for (final entry in needed.entries) {
      final maxPeriod = entry.value.reduce((a, b) => a > b ? a : b);
      final bars = await service.getDailyBars(entry.key, limit: maxPeriod + 5);
      // Excluimos la vela de hoy (si existe) para comparar contra la media
      // de cierres anteriores.
      final today = DateTime.now().toUtc();
      final closes = bars
          .where((b) {
            final t = b.time.toUtc();
            return !(t.year == today.year && t.month == today.month && t.day == today.day);
          })
          .map((b) => b.close)
          .toList();
      for (final p in entry.value) {
        final v = Indicators.sma(closes, p);
        if (v != null) out[AlertEngine.smaKey(entry.key, p)] = v;
      }
    }
    return out;
  }

  /// Evalúa las alertas guardadas. Si se pasan [quotes] (app abierta) no
  /// se vuelven a pedir precios. Devuelve la lista actualizada.
  Future<List<PriceAlert>> checkAlerts({
    Map<String, Quote>? quotes,
    Map<String, double>? smas,
  }) async {
    final alerts = await store.loadAlerts();
    final active = alerts.where((a) => a.isActive).toList();
    if (active.isEmpty) return alerts;
    final q = quotes ??
        await service.getSnapshots(active.map((a) => a.symbol).toSet().toList());
    final s = smas ?? await smasFor(active);
    final hits = AlertEngine.evaluate(active, q, smas: s);
    if (hits.isEmpty) return alerts;
    final byId = {for (final h in hits) h.updated.id: h.updated};
    final updated = alerts.map((a) => byId[a.id] ?? a).toList();
    await store.saveAlerts(updated);
    for (final h in hits) {
      await notifications.show(
        kind: NotificationKind.alert,
        key: 'alert-${h.updated.id}-${dayKey(DateTime.now())}',
        title: '🔔 ${h.updated.symbol}',
        body: h.message,
      );
    }
    return updated;
  }

  /// Notifica órdenes que se ejecutaron/cancelaron/rechazaron desde la
  /// última revisión (respaldo para cuando la app está cerrada).
  Future<void> checkClosedOrders() async {
    final last = await store.loadLastOrderCheck() ??
        DateTime.now().subtract(const Duration(hours: 1));
    final now = DateTime.now();
    final orders = await service.getOrders(status: 'closed', limit: 50);
    for (final o in orders) {
      final changedAt = o.filledAt ?? o.updatedAt;
      if (changedAt == null || !changedAt.isAfter(last)) continue;
      await notifyOrder(o);
    }
    await store.saveLastOrderCheck(now);
  }

  Future<void> notifyOrder(OrderInfo o, {String? event}) async {
    final status = event == 'partial_fill' ? 'partially_filled' : (event == 'fill' ? 'filled' : o.status);
    if (!{'filled', 'partially_filled', 'canceled', 'rejected', 'expired'}.contains(status)) return;
    final key = 'order-${o.id}-$status';
    if (!await store.markOrderNotified(key)) return;
    final verb = o.isBuy ? 'Compra' : 'Venta';
    final body = switch (status) {
      'filled' || 'partially_filled' =>
        '$verb de ${Fmt.qty(o.filledQty ?? o.qty ?? 0)} ${o.symbol} a '
            '${Fmt.usd(o.filledAvgPrice ?? 0)}'
            '${status == "partially_filled" ? " (parcial)" : ""}',
      'canceled' => '$verb de ${o.symbol} cancelada',
      'expired' => '$verb de ${o.symbol} expiró sin ejecutarse',
      _ => '$verb de ${o.symbol} fue rechazada por el bróker',
    };
    await notifications.show(
      kind: NotificationKind.order,
      key: key,
      title: status == 'filled' ? '✅ Orden ejecutada' : '📋 Orden ${o.statusLabel.toLowerCase()}',
      body: body,
    );
  }

  /// Ejecuta las compras periódicas que correspondan. Solo con el mercado
  /// abierto (para que la compra a mercado se ejecute al precio del momento).
  Future<void> runDcaPlans(MarketClock clock) async {
    if (!clock.isOpen) return;
    final plans = await store.loadDcaPlans();
    if (plans.every((p) => !p.isDue(clock.nyNow))) return;
    final updated = <DcaPlan>[];
    for (final plan in plans) {
      if (!plan.isDue(clock.nyNow)) {
        updated.add(plan);
        continue;
      }
      final period = plan.periodKey(clock.nyNow);
      final clientId = 'dca-${plan.id.substring(0, 8)}-$period';
      try {
        await service.placeOrder(
          symbol: plan.symbol,
          side: 'buy',
          notional: plan.amountUsd,
          clientOrderId: clientId,
        );
        await notifications.show(
          kind: NotificationKind.dca,
          key: clientId,
          title: '🤖 Compra automática',
          body: 'Se envió la compra de ${Fmt.usd(plan.amountUsd)} en ${plan.symbol} '
              '(${plan.scheduleLabel.toLowerCase()}).',
        );
        updated.add(plan.copyWith(lastRunKey: period));
      } on AlpacaException catch (e) {
        if (e.message.toLowerCase().contains('client_order_id')) {
          // Ya se había enviado (desde la app o el segundo plano).
          updated.add(plan.copyWith(lastRunKey: period));
        } else {
          updated.add(plan);
          if (await store.markOrderNotified('dcafail-$clientId')) {
            await notifications.show(
              kind: NotificationKind.dca,
              key: 'dcafail-$clientId',
              title: '⚠️ Compra automática no realizada',
              body: '${plan.symbol}: ${e.message}',
            );
          }
        }
      }
    }
    await store.saveDcaPlans(updated);
  }

  /// Resumen al cierre: una vez por día hábil, después de las 16:00 de NY.
  Future<void> maybeDailySummary(MarketClock clock) async {
    final ny = clock.nyNow;
    if (clock.isOpen || ny.weekday > 5 || ny.hour < 16) return;
    final key = dayKey(ny);
    if (await store.loadLastSummaryDay() == key) return;
    if (!await service.isTradingDay(ny)) {
      await store.saveLastSummaryDay(key);
      return;
    }
    final account = await service.getAccount();
    final positions = await service.getPositions();
    final settings = await store.loadSettings();
    final hidden = settings.hideBalances;
    double? fx;
    if (settings.showClp && settings.preferClp) {
      try {
        fx = await FxService().latest();
      } catch (_) {}
    }
    String amount(double usd) =>
        fx == null ? Fmt.usd(usd, hidden: hidden) : Fmt.clp(usd * fx, hidden: hidden);
    final up = account.dayChange >= 0;
    final b = StringBuffer(hidden
        ? 'Hoy tu portafolio ${up ? "subió" : "bajó"} ${Fmt.pct(account.dayChangePercent)}.'
        : 'Hoy ${up ? "ganaste" : "perdiste"} ${amount(account.dayChange.abs())} '
            '(${Fmt.pct(account.dayChangePercent)}). Tienes en total ${amount(account.equity)}.');
    if (positions.isNotEmpty) {
      final quotes = await service.getSnapshots(positions.map((p) => p.symbol).toList());
      final movers = quotes.values.toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
      if (movers.isNotEmpty) {
        b.write('\nMejor: ${movers.first.symbol} ${Fmt.pct(movers.first.changePercent)}');
        if (movers.length > 1) {
          b.write(' · Peor: ${movers.last.symbol} ${Fmt.pct(movers.last.changePercent)}');
        }
      }
    }
    await notifications.show(
      kind: NotificationKind.summary,
      key: 'summary-$key',
      title: account.dayChange >= 0 ? '📈 Cierre del mercado' : '📉 Cierre del mercado',
      body: b.toString(),
    );
    await store.saveLastSummaryDay(key);
  }

  Future<void> updateHomeWidget({required bool hidden}) async {
    final account = await service.getAccount();
    final settings = await store.loadSettings();
    double? fx;
    if (settings.showClp && settings.preferClp) {
      try {
        fx = await FxService().latest();
      } catch (_) {}
    }
    await HomeWidgetService.update(
      value: account.equity,
      dayChange: account.dayChange,
      dayChangePercent: account.dayChangePercent,
      hidden: hidden,
      isLive: service.credentials.isLive,
      usdClp: fx,
    );
  }
}
