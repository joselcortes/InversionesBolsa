import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationKind {
  alert('alertas_precio', 'Alertas de precio',
      'Avisos cuando una acción cumple una alerta que definiste'),
  order('ordenes', 'Órdenes', 'Avisos cuando se ejecuta, cancela o rechaza una orden'),
  summary('resumen', 'Resumen diario', 'Resumen de tu portafolio al cierre del mercado'),
  dca('compras_auto', 'Compras automáticas', 'Resultado de tus planes de compra periódica');

  final String channelId;
  final String channelName;
  final String description;
  const NotificationKind(this.channelId, this.channelName, this.description);
}

/// Notificaciones locales. Funciona tanto con la app abierta como desde la
/// tarea en segundo plano.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// En la versión web no hay notificaciones del sistema: los avisos se
  /// emiten aquí y la app los muestra como mensaje en pantalla.
  static final inAppMessages = StreamController<String>.broadcast();

  Future<void> init({bool requestPermission = true}) async {
    if (_ready || kIsWeb) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (requestPermission) {
      await androidImpl?.requestNotificationsPermission();
    }
    for (final k in NotificationKind.values) {
      await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
        k.channelId,
        k.channelName,
        description: k.description,
        importance: k == NotificationKind.summary ? Importance.defaultImportance : Importance.max,
      ));
    }
    _ready = true;
  }

  /// [key] identifica la notificación: la misma clave reemplaza a la
  /// anterior en vez de duplicarla (útil si la app y el proceso en segundo
  /// plano detectan lo mismo).
  Future<void> show({
    required NotificationKind kind,
    required String key,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      inAppMessages.add('$title · $body');
      return;
    }
    await _plugin.show(
      id: key.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kind.channelId,
          kind.channelName,
          channelDescription: kind.description,
          importance: kind == NotificationKind.summary
              ? Importance.defaultImportance
              : Importance.max,
          priority: kind == NotificationKind.summary ? Priority.defaultPriority : Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }
}
