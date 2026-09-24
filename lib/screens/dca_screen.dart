import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dca_plan.dart';
import '../providers/portfolio_provider.dart';
import '../services/auth_gate_service.dart';
import '../services/background_service.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';
import 'symbol_search_sheet.dart';

/// Planes de compra periódica automática (DCA).
class DcaScreen extends StatelessWidget {
  const DcaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final plans = provider.dcaPlans;
    final monthly = plans.where((p) => p.enabled).fold<double>(
        0, (s, p) => s + (p.frequency == DcaFrequency.weekly ? p.amountUsd * 52 / 12 : p.amountUsd));

    return Scaffold(
      appBar: AppBar(title: const Text('Compras automáticas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _NewPlanSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo plan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          InfoBanner(
            'Invierte un monto fijo en US\$ cada semana o mes, sin mirar el precio (promedias tu costo '
            'en el tiempo). La compra se envía a mercado con la bolsa abierta'
            '${BackgroundService.supported ? ", aunque la app esté cerrada" : " cuando abras la app"}, '
            'y te llega una notificación.'
            '${provider.isLive ? "\n\n⚠️ Estás en modo REAL: estas compras usan dinero real." : ""}',
            icon: Icons.autorenew_rounded,
          ),
          const HelpLink('dca', text: '¿Por qué invertir de a poco?'),
          const SizedBox(height: 8),
          if (plans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Aprox. ${provider.money(monthly)} al mes en planes activos'
                  '${provider.clp(monthly) != null ? " (${provider.clp(monthly)})" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          if (plans.isEmpty)
            const EmptyState(
              icon: Icons.savings_rounded,
              title: 'Sin planes todavía',
              message: 'Ejemplo: US\$50 en VOO cada lunes.',
            )
          else
            ...plans.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('${Fmt.usd(p.amountUsd)} en ${p.symbol}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${p.scheduleLabel}${p.lastRunKey != null ? " · última cuota: ${p.lastRunKey}" : ""}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    leading: Switch(
                      value: p.enabled,
                      onChanged: (v) => provider.setDcaEnabled(p.id, v),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Eliminar plan',
                            message: '¿Eliminar la compra automática de ${p.symbol}?',
                            confirmLabel: 'Eliminar',
                            destructive: true);
                        if (ok) await provider.removeDcaPlan(p.id);
                      },
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _NewPlanSheet extends StatefulWidget {
  const _NewPlanSheet();

  @override
  State<_NewPlanSheet> createState() => _NewPlanSheetState();
}

class _NewPlanSheetState extends State<_NewPlanSheet> {
  String _symbol = 'VOO';
  final _amountCtrl = TextEditingController(text: '50');
  DcaFrequency _freq = DcaFrequency.weekly;
  int _weekday = 1;
  int _monthDay = 5;
  bool _startNow = false;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<PortfolioProvider>();
    final amount = Fmt.parse(_amountCtrl.text);
    if (amount == null || amount < 1) {
      showSnack(context, 'El monto mínimo es US\$1');
      return;
    }
    final asset = provider.assetInfo(_symbol);
    if (asset != null && !asset.fractionable) {
      showSnack(context, '$_symbol no permite compras por monto (no es fraccionable)');
      return;
    }
    final day = _freq == DcaFrequency.weekly ? _weekday : _monthDay;
    final schedule = _freq == DcaFrequency.weekly
        ? 'cada ${DcaPlan.weekdayNames[day]}'
        : 'el día $day de cada mes';
    final ok = await confirmDialog(
      context,
      title: 'Activar compra automática',
      message: 'Se comprarán ${Fmt.usd(amount)} de $_symbol $schedule, sin pedir confirmación '
          'cada vez.${provider.isLive ? "\n\n⚠️ Modo REAL: usará dinero real." : ""}',
      confirmLabel: 'Activar',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final auth = await AuthGateService().confirmIdentity(
      reason: 'Confirma para activar la compra automática',
      strict: provider.isLive,
    );
    if (!mounted) return;
    if (auth != AuthResult.ok) {
      setState(() => _saving = false);
      showSnack(context, AuthGateService.failureMessage(auth));
      return;
    }
    await provider.addDcaPlan(
      symbol: _symbol,
      amountUsd: amount,
      frequency: _freq,
      day: day,
      startThisPeriod: _startNow,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            const Text('Nuevo plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(_symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(context.watch<PortfolioProvider>().assetInfo(_symbol)?.name ?? 'Toca para cambiar'),
                trailing: const Icon(Icons.search_rounded),
                onTap: () async {
                  final s = await showSymbolSearch(context, title: '¿Qué quieres comprar?');
                  if (s != null) setState(() => _symbol = s);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto por compra (US\$)'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<DcaFrequency>(
              segments: const [
                ButtonSegment(value: DcaFrequency.weekly, label: Text('Semanal')),
                ButtonSegment(value: DcaFrequency.monthly, label: Text('Mensual')),
              ],
              selected: {_freq},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _freq = s.first),
            ),
            const SizedBox(height: 12),
            if (_freq == DcaFrequency.weekly)
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Día de la semana'),
                items: [
                  for (var d = 1; d <= 5; d++)
                    DropdownMenuItem(value: d, child: Text(DcaPlan.weekdayNames[d])),
                ],
                onChanged: (v) => setState(() => _weekday = v ?? 1),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _monthDay,
                decoration: const InputDecoration(labelText: 'Día del mes'),
                items: [
                  for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setState(() => _monthDay = v ?? 1),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hacer la primera compra en este periodo'),
              subtitle: Text(
                'Si ya pasó el día elegido, compra en la próxima apertura. Si no, parte el próximo periodo.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              value: _startNow,
              onChanged: (v) => setState(() => _startNow = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Activar plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
