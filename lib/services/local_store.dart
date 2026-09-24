import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dca_plan.dart';
import '../models/price_alert.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool hideBalances;
  final bool appLock;
  final bool showClp;

  /// Mostrar los saldos primero en pesos (y el dólar como dato secundario).
  final bool preferClp;
  final bool backgroundChecks;
  final bool dailySummary;
  final bool orderNotifications;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.hideBalances = false,
    this.appLock = false,
    this.showClp = true,
    this.preferClp = true,
    this.backgroundChecks = true,
    this.dailySummary = true,
    this.orderNotifications = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? hideBalances,
    bool? appLock,
    bool? showClp,
    bool? preferClp,
    bool? backgroundChecks,
    bool? dailySummary,
    bool? orderNotifications,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        hideBalances: hideBalances ?? this.hideBalances,
        appLock: appLock ?? this.appLock,
        showClp: showClp ?? this.showClp,
        preferClp: preferClp ?? this.preferClp,
        backgroundChecks: backgroundChecks ?? this.backgroundChecks,
        dailySummary: dailySummary ?? this.dailySummary,
        orderNotifications: orderNotifications ?? this.orderNotifications,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'hideBalances': hideBalances,
        'appLock': appLock,
        'showClp': showClp,
        'preferClp': preferClp,
        'backgroundChecks': backgroundChecks,
        'dailySummary': dailySummary,
        'orderNotifications': orderNotifications,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        hideBalances: j['hideBalances'] as bool? ?? false,
        appLock: j['appLock'] as bool? ?? false,
        showClp: j['showClp'] as bool? ?? true,
        preferClp: j['preferClp'] as bool? ?? true,
        backgroundChecks: j['backgroundChecks'] as bool? ?? true,
        dailySummary: j['dailySummary'] as bool? ?? true,
        orderNotifications: j['orderNotifications'] as bool? ?? true,
      );
}

/// Todo lo que la app guarda localmente en el teléfono (no viaja a ningún
/// servidor propio). Antes de cada lectura se recarga desde disco, porque la
/// tarea en segundo plano corre en otro isolate y también escribe aquí.
class LocalStore {
  static const _alertsKey = 'price_alerts_v1';
  static const _watchlistKey = 'watchlist_v1';
  static const _settingsKey = 'settings_v1';
  static const _dcaKey = 'dca_plans_v1';
  static const _notifiedOrdersKey = 'notified_orders_v1';
  static const _lastOrderCheckKey = 'last_order_check_v1';
  static const _lastSummaryKey = 'last_summary_day_v1';

  Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  Future<List<T>> _loadList<T>(String key, T Function(Map<String, dynamic>) parse) async {
    final raw = (await _prefs()).getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PriceAlert>> loadAlerts() => _loadList(_alertsKey, PriceAlert.fromJson);

  Future<void> saveAlerts(List<PriceAlert> alerts) async {
    await (await _prefs())
        .setString(_alertsKey, jsonEncode(alerts.map((a) => a.toJson()).toList()));
  }

  Future<List<DcaPlan>> loadDcaPlans() => _loadList(_dcaKey, DcaPlan.fromJson);

  Future<void> saveDcaPlans(List<DcaPlan> plans) async {
    await (await _prefs())
        .setString(_dcaKey, jsonEncode(plans.map((p) => p.toJson()).toList()));
  }

  /// null = nunca se guardó (usar la lista por defecto).
  Future<List<String>?> loadWatchlist() async =>
      (await _prefs()).getStringList(_watchlistKey);

  Future<void> saveWatchlist(List<String> symbols) async {
    await (await _prefs()).setStringList(_watchlistKey, symbols);
  }

  Future<AppSettings> loadSettings() async {
    final raw = (await _prefs()).getString(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await (await _prefs()).setString(_settingsKey, jsonEncode(s.toJson()));
  }

  /// Marca la notificación de una orden como enviada. Devuelve false si ya
  /// se había notificado (evita avisos duplicados entre la app y el proceso
  /// en segundo plano).
  Future<bool> markOrderNotified(String key) async {
    final prefs = await _prefs();
    final list = prefs.getStringList(_notifiedOrdersKey) ?? [];
    if (list.contains(key)) return false;
    list.add(key);
    await prefs.setStringList(
        _notifiedOrdersKey, list.length > 300 ? list.sublist(list.length - 300) : list);
    return true;
  }

  Future<DateTime?> loadLastOrderCheck() async =>
      DateTime.tryParse((await _prefs()).getString(_lastOrderCheckKey) ?? '');

  Future<void> saveLastOrderCheck(DateTime t) async {
    await (await _prefs()).setString(_lastOrderCheckKey, t.toIso8601String());
  }

  Future<String?> loadLastSummaryDay() async => (await _prefs()).getString(_lastSummaryKey);

  Future<void> saveLastSummaryDay(String day) async {
    await (await _prefs()).setString(_lastSummaryKey, day);
  }
}
