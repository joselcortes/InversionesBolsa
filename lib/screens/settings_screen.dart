import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../services/auth_gate_service.dart';
import '../services/background_service.dart';
import '../services/home_widget_service.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'activity_screen.dart';
import 'dca_screen.dart';
import 'tax_report_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _isLive = false;
  bool _saving = false;
  bool _obscureSecret = true;

  @override
  void dispose() {
    _keyIdCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLiveModeIfNeeded() async {
    if (!_isLive) return;
    final confirmed = await confirmDialog(
      context,
      title: '⚠️ Vas a activar dinero real',
      message: 'En modo real, las compras y ventas que hagas en esta app usan tu '
          'dinero de verdad en tu cuenta de Alpaca, sin posibilidad de deshacer '
          'la orden una vez ejecutada. Asegúrate de haber probado todo primero '
          'en modo paper (simulación).\n\n¿Confirmas que quieres usar tus API '
          'keys de modo real (live)?',
      confirmLabel: 'Sí, usar modo real',
      destructive: true,
    );
    if (!confirmed) setState(() => _isLive = false);
  }

  Future<void> _save() async {
    if (_keyIdCtrl.text.trim().isEmpty || _secretCtrl.text.trim().isEmpty) {
      showSnack(context, 'Completa API Key ID y Secret Key');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<PortfolioProvider>();
    final ok = await provider.saveCredentials(
      keyId: _keyIdCtrl.text,
      secretKey: _secretCtrl.text,
      isLive: _isLive,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    showSnack(context, ok ? 'Conectado correctamente a Alpaca' : 'No se pudo conectar. Revisa tus API keys.');
    if (ok) {
      _keyIdCtrl.clear();
      _secretCtrl.clear();
    }
  }

  Future<void> _toggleAppLock(bool enable) async {
    final provider = context.read<PortfolioProvider>();
    // Tanto para activar como para desactivar se pide identidad: así nadie
    // con el teléfono en la mano puede quitar el bloqueo.
    final r = await AuthGateService().confirmIdentity(
      reason: enable ? 'Confirma para activar el bloqueo' : 'Confirma para quitar el bloqueo',
      strict: true,
    );
    if (!mounted) return;
    if (r != AuthResult.ok) {
      showSnack(context, AuthGateService.failureMessage(r));
      return;
    }
    await provider.updateSettings(provider.settings.copyWith(appLock: enable));
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final s = provider.settings;
    final scheme = Theme.of(context).colorScheme;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 4),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          if (provider.isConfigured)
            Card(
              color: provider.isLive ? scheme.errorContainer : scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      provider.isLive ? Icons.warning_amber_rounded : Icons.science_rounded,
                      color: provider.isLive ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.isLive
                            ? 'Conectado en modo REAL (dinero real)'
                            : 'Conectado en modo práctica (dinero simulado)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: provider.isLive ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ---------------------------------------------------- Automatización
          if (provider.isConfigured) ...[
            header('Automatización'),
            if (!BackgroundService.supported)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: InfoBanner('En esta plataforma las tareas automáticas solo corren con la app abierta.'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Revisar alertas en segundo plano'),
              subtitle: const Text('Cada ~15 min aunque la app esté cerrada'),
              value: s.backgroundChecks,
              onChanged: (v) => provider.updateSettings(s.copyWith(backgroundChecks: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisar cuando se ejecute una orden'),
              subtitle: const Text('Compras, ventas, stop-loss que saltan, cancelaciones'),
              value: s.orderNotifications,
              onChanged: (v) => provider.updateSettings(s.copyWith(orderNotifications: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Resumen diario al cierre'),
              subtitle: const Text('Ganancia del día y mejores/peores acciones (después de las 16:00 NY)'),
              value: s.dailySummary,
              onChanged: (v) => provider.updateSettings(s.copyWith(dailySummary: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.autorenew_rounded),
              title: const Text('Compras automáticas (DCA)'),
              subtitle: Text(provider.dcaPlans.isEmpty
                  ? 'Invertir un monto fijo cada semana o mes'
                  : '${provider.dcaPlans.where((p) => p.enabled).length} plan(es) activo(s)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _push(const DcaScreen()),
            ),
            if (BackgroundService.supported)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Agregar widget a la pantalla de inicio'),
                subtitle: const Text('Valor del portafolio y variación del día'),
                onTap: () async {
                  final ok = await HomeWidgetService.requestPin();
                  if (!ok && context.mounted) {
                    showSnack(context,
                        'Tu launcher no permite agregarlo desde aquí: mantén presionada la pantalla de inicio → Widgets → Inversiones.');
                  }
                },
              ),

            // ------------------------------------------------------- Reportes
            header('Reportes'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Historial de movimientos'),
              subtitle: const Text('Compras, ventas, dividendos y depósitos'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _push(const ActivityScreen()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('Reporte para el SII'),
              subtitle: const Text('Ganancias de capital y dividendos en pesos, exportable'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _push(const TaxReportScreen()),
            ),
          ],

          // ------------------------------------------------------ Apariencia
          header('Apariencia y moneda'),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode_rounded, size: 16)),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_rounded, size: 16)),
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.phone_android_rounded, size: 16)),
            ],
            selected: {s.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (v) => provider.updateSettings(s.copyWith(themeMode: v.first)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar montos en pesos chilenos'),
            subtitle: Text(provider.usdClp == null
                ? 'Usa el dólar observado del Banco Central'
                : 'Dólar observado: ${Fmt.clp(provider.usdClp!)}'),
            value: s.showClp,
            onChanged: (v) => provider.updateSettings(s.copyWith(showClp: v)),
          ),
          if (s.showClp)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Row(
                children: [
                  Flexible(child: Text('Pesos como moneda principal')),
                  InfoTip('dolar'),
                ],
              ),
              subtitle: const Text('Saldos y ganancias en pesos grande, y en dólares chico'),
              value: s.preferClp,
              onChanged: (v) => provider.updateSettings(s.copyWith(preferClp: v)),
            ),

          // ---------------------------------------------------- Privacidad
          header('Privacidad y seguridad'),
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: InfoBanner(
                'Versión web: tus claves quedan guardadas solo en este navegador. Úsala en computadores '
                'de confianza y presiona "Desconectar cuenta" si usas uno compartido. Las órdenes con '
                'dinero real solo se pueden hacer desde la app del celular.',
                icon: Icons.language_rounded,
              ),
            )
          else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bloquear la app con huella/PIN'),
              subtitle: const Text('Al abrir y al volver tras 1 minuto'),
              value: s.appLock,
              onChanged: _toggleAppLock,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ocultar saldos'),
            subtitle: const Text('También desde el ojo en Portafolio'),
            value: s.hideBalances,
            onChanged: (v) => provider.updateSettings(s.copyWith(hideBalances: v)),
          ),

          // -------------------------------------------------------- Cuenta
          header(provider.isConfigured ? 'Cambiar cuenta de Alpaca' : 'Conectar cuenta de Alpaca'),
          Text(
            'Tus API keys se guardan cifradas solo en este ${kIsWeb ? "navegador" : "teléfono"}. Nunca se envían a nadie más que a Alpaca.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const Wrap(
            spacing: 12,
            children: [
              HelpLink('api_keys', text: '¿Cómo saco mis claves?'),
              HelpLink('paper', text: '¿Práctica o real?'),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyIdCtrl,
            decoration: const InputDecoration(labelText: 'API Key ID'),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretCtrl,
            decoration: InputDecoration(
              labelText: 'Secret Key',
              suffixIcon: IconButton(
                icon: Icon(_obscureSecret ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
              ),
            ),
            obscureText: _obscureSecret,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar modo real (live)'),
            subtitle: Text(
              _isLive ? 'Las órdenes usarán dinero real' : 'Modo paper: dinero simulado, recomendado para empezar',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            value: _isLive,
            onChanged: (v) async {
              setState(() => _isLive = v);
              await _confirmLiveModeIfNeeded();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Conectar'),
              ),
            ),
          ),
          if (provider.isConfigured) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: 'Desconectar cuenta',
                  message: 'Se borrarán tus API keys guardadas en este teléfono y se detendrán las '
                      'tareas automáticas.',
                  confirmLabel: 'Desconectar',
                  destructive: true,
                );
                if (confirmed && context.mounted) {
                  await context.read<PortfolioProvider>().logout();
                }
              },
              child: const Text('Desconectar cuenta'),
            ),
          ],
        ],
      ),
    );
  }
}
