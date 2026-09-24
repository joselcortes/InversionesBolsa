import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import 'alpaca_service.dart';
import 'automation_runner.dart';
import 'credentials_service.dart';
import 'local_store.dart';
import 'notification_service.dart';

const _taskName = 'inversiones_automation';
const _uniqueName = 'inversiones_automation_periodic';

/// Punto de entrada de la tarea en segundo plano (corre en otro isolate,
/// aunque la app esté cerrada). Android la ejecuta aprox. cada 15 min,
/// pudiendo retrasarla por ahorro de batería.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await initializeDateFormatting('es');
      final creds = await CredentialsService().load();
      if (creds == null) return true;
      final notifications = NotificationService();
      await notifications.init(requestPermission: false);
      await AutomationRunner(
        service: AlpacaService(creds),
        store: LocalStore(),
        notifications: notifications,
      ).runAll();
    } catch (_) {
      // Nunca devolvemos false: haría que Android reintente en bucle.
    }
    return true;
  });
}

class BackgroundService {
  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> initialize() async {
    if (!supported) return;
    await Workmanager().initialize(backgroundDispatcher);
  }

  static Future<void> schedule() async {
    if (!supported) return;
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancel() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}
