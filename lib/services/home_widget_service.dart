import 'package:home_widget/home_widget.dart';

import '../utils/formatters.dart';

/// Actualiza el widget de la pantalla de inicio (Android) con el valor del
/// portafolio y la variación del día.
class HomeWidgetService {
  static const _provider =
      'com.inversionesbolsa.inversiones_bolsa.PortfolioWidgetProvider';

  /// Pide al launcher agregar el widget a la pantalla de inicio. Devuelve
  /// false si el launcher no lo soporta.
  static Future<bool> requestPin() async {
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(qualifiedAndroidName: _provider);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> update({
    required double value,
    required double dayChange,
    required double dayChangePercent,
    required bool hidden,
    required bool isLive,
    double? usdClp,
  }) async {
    try {
      final now = DateTime.now();
      final fx = usdClp;
      String amount(double usd) => fx == null ? Fmt.usd(usd, hidden: hidden) : Fmt.clp(usd * fx, hidden: hidden);
      String signed(double usd) {
        if (fx == null) return Fmt.usdSigned(usd);
        final v = usd * fx;
        return '${v >= 0 ? "+" : "−"}${Fmt.clp(v.abs())}';
      }

      await HomeWidget.saveWidgetData<String>('value', amount(value));
      await HomeWidget.saveWidgetData<String>(
        'change',
        hidden
            ? '${Fmt.pct(dayChangePercent)} hoy'
            : '${dayChange >= 0 ? "Ganaste" : "Perdiste"} ${signed(dayChange)} (${Fmt.pct(dayChangePercent)}) hoy',
      );
      await HomeWidget.saveWidgetData<bool>('up', dayChange >= 0);
      await HomeWidget.saveWidgetData<String>('mode', isLive ? 'REAL' : 'PRÁCTICA');
      await HomeWidget.saveWidgetData<String>(
        'updated',
        'Act. ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (_) {
      // Plataformas sin widget (iOS sin extensión, desktop, tests): se ignora.
    }
  }
}
