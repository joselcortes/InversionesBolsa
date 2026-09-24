import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/price_alert.dart';
import '../providers/portfolio_provider.dart';
import '../services/background_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'symbol_search_sheet.dart';

/// Hoja para crear una alerta. Se usa desde la pestaña Alertas y desde el
/// detalle de una acción (con el símbolo ya puesto).
Future<void> showAlertSheet(BuildContext context, {String? symbol}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NewAlertSheet(initialSymbol: symbol),
  );
  if (created == true && context.mounted) {
    showSnack(
      context,
      BackgroundService.supported
          ? 'Alerta creada. Se revisa en vivo y cada ~15 min con la app cerrada.'
          : 'Alerta creada. Se revisa mientras la app esté abierta.',
    );
  }
}

class _NewAlertSheet extends StatefulWidget {
  final String? initialSymbol;
  const _NewAlertSheet({this.initialSymbol});

  @override
  State<_NewAlertSheet> createState() => _NewAlertSheetState();
}

class _NewAlertSheetState extends State<_NewAlertSheet> {
  late String _symbol;
  final _targetCtrl = TextEditingController();
  AlertType _type = AlertType.price;
  AlertDirection _direction = AlertDirection.above;
  bool _repeating = false;
  int _smaPeriod = 50;

  @override
  void initState() {
    super.initState();
    final p = context.read<PortfolioProvider>();
    _symbol = widget.initialSymbol ?? (p.watchlist.isNotEmpty ? p.watchlist.first : '');
    _prefill();
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    final q = context.read<PortfolioProvider>().quotes[_symbol];
    _targetCtrl.text = switch (_type) {
      AlertType.price => q == null ? '' : Fmt.number(q.price),
      AlertType.dayChange => '5',
      AlertType.volumeSpike => '2',
      AlertType.smaCross => '',
    };
  }

  String get _targetLabel => switch (_type) {
        AlertType.price => 'Precio objetivo (US\$)',
        AlertType.dayChange => 'Variación en el día (%)',
        AlertType.volumeSpike => 'Veces el volumen de ayer (ej: 2)',
        AlertType.smaCross => '',
      };

  Future<void> _save() async {
    final provider = context.read<PortfolioProvider>();
    final double? target =
        _type == AlertType.smaCross ? _smaPeriod.toDouble() : Fmt.parse(_targetCtrl.text);
    if (_symbol.isEmpty || target == null || target <= 0) {
      showSnack(context, 'Completa símbolo y un valor válido');
      return;
    }
    await provider.addAlert(
      symbol: _symbol,
      type: _type,
      direction: _direction,
      target: target,
      repeating: _repeating,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final q = provider.quotes[_symbol];
    final showDirection = _type != AlertType.volumeSpike;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nueva alerta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Te avisamos al celular cuando pase. Las alertas no compran ni venden.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const HelpLink('alertas', text: '¿Qué tipos de alerta hay?'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(_symbol.isEmpty ? 'Elegir acción' : _symbol,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: q == null
                    ? null
                    : Text('${Fmt.usd(q.price)} · ${Fmt.pct(q.changePercent)} hoy'),
                trailing: const Icon(Icons.search_rounded),
                onTap: () async {
                  final s = await showSymbolSearch(context);
                  if (s != null) {
                    setState(() => _symbol = s);
                    _prefill();
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AlertType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo de alerta'),
              items: const [
                DropdownMenuItem(value: AlertType.price, child: Text('Precio llega a…')),
                DropdownMenuItem(value: AlertType.dayChange, child: Text('Variación del día (%)')),
                DropdownMenuItem(value: AlertType.volumeSpike, child: Text('Volumen inusual')),
                DropdownMenuItem(value: AlertType.smaCross, child: Text('Cruce de media móvil')),
              ],
              onChanged: (t) {
                if (t == null) return;
                setState(() => _type = t);
                _prefill();
              },
            ),
            const SizedBox(height: 12),
            if (showDirection)
              SegmentedButton<AlertDirection>(
                segments: [
                  ButtonSegment(
                    value: AlertDirection.above,
                    label: Text(_type == AlertType.smaCross ? 'Cruza hacia arriba' : 'Sube'),
                    icon: const Icon(Icons.trending_up_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: AlertDirection.below,
                    label: Text(_type == AlertType.smaCross ? 'Cruza hacia abajo' : 'Baja'),
                    icon: const Icon(Icons.trending_down_rounded, size: 16),
                  ),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _direction = s.first),
              ),
            const SizedBox(height: 12),
            if (_type == AlertType.smaCross)
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 20, label: Text('Media 20 d')),
                  ButtonSegment(value: 50, label: Text('Media 50 d')),
                  ButtonSegment(value: 200, label: Text('Media 200 d')),
                ],
                selected: {_smaPeriod},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _smaPeriod = s.first),
              )
            else
              TextField(
                controller: _targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _targetLabel),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir'),
              subtitle: Text(
                'Puede volver a avisar otro día (máximo una vez al día). Si no, se desactiva al cumplirse.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              value: _repeating,
              onChanged: (v) => setState(() => _repeating = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Crear alerta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  IconData _icon(PriceAlert a) => switch (a.type) {
        AlertType.price => a.isAbove ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        AlertType.dayChange => Icons.percent_rounded,
        AlertType.volumeSpike => Icons.bar_chart_rounded,
        AlertType.smaCross => Icons.stacked_line_chart_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('d MMM, HH:mm', 'es');

    if (!provider.isConfigured) {
      return const NotConnectedScaffold(
        title: 'Alertas',
        icon: Icons.notifications_active_rounded,
        message: 'Ve a Ajustes para poder crear alertas.',
      );
    }

    final sorted = [...provider.alerts]..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(
            tooltip: 'Nueva alerta',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showAlertSheet(context),
          ),
        ],
      ),
      body: sorted.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Sin alertas todavía',
                message: 'Te avisamos cuando una acción llegue a un precio, se mueva fuerte en el día, '
                    'tenga volumen inusual o cruce su media móvil.',
                actionLabel: 'Crear alerta',
                onAction: () => showAlertSheet(context),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: sorted.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return InfoBanner(
                    BackgroundService.supported && provider.settings.backgroundChecks
                        ? 'Se revisan en tiempo real con la app abierta y cada ~15 min con el celular '
                            'bloqueado (Android puede atrasarlo para ahorrar batería).'
                        : 'Se revisan en tiempo real mientras la app esté abierta. '
                            'Activa la revisión en segundo plano en Ajustes.',
                  );
                }
                final alert = sorted[i - 1];
                final q = provider.quotes[alert.symbol];
                final color = !alert.isActive
                    ? scheme.onSurfaceVariant
                    : alert.isAbove
                        ? AppTheme.up
                        : AppTheme.down;
                final status = alert.triggered
                    ? '${alert.repeating ? "Última vez" : "Cumplida"} el ${formatter.format(alert.triggeredAt!)}'
                    : 'Activa desde el ${formatter.format(alert.createdAt)}';
                return Card(
                  color: scheme.surfaceContainerHigh,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(_icon(alert), color: color),
                    title: Text(
                      alert.description,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: alert.isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      [
                        status,
                        if (alert.repeating) '🔁 Repetible',
                        if (q != null) 'Ahora ${Fmt.usd(q.price)} (${Fmt.pct(q.changePercent)})',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: alert.triggered && !alert.repeating ? AppTheme.up : scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!alert.isActive)
                          IconButton(
                            tooltip: 'Reactivar',
                            icon: const Icon(Icons.replay_rounded),
                            onPressed: () => provider.rearmAlert(alert.id),
                          ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => provider.removeAlert(alert.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
