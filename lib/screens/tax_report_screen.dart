import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/portfolio_provider.dart';
import '../services/fx_service.dart';
import '../theme/app_theme.dart';
import '../utils/file_download.dart';
import '../utils/formatters.dart';
import '../utils/tax_calculator.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';

/// Resumen anual referencial para la Operación Renta: ganancias de capital
/// realizadas (FIFO) y dividendos, en US$ y en pesos con el dólar observado
/// de cada fecha.
class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});

  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
  static const _types = ['FILL', 'DIV', 'DIVCGL', 'DIVCGS', 'DIVROC', 'DIVTXEX', 'DIVNRA'];
  final _fx = FxService();
  int _year = DateTime.now().year - (DateTime.now().month <= 4 ? 1 : 0);
  TaxReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<PortfolioProvider>().requireService();
      final acts = await service.getActivities(types: _types);
      // Tipo de cambio de todos los años involucrados (las compras de años
      // anteriores definen el costo de lo vendido este año).
      final years = {...acts.map((a) => a.date.year).where((y) => y <= _year), _year};
      final series = <int, Map<String, double>>{};
      for (final y in years) {
        series[y] = await _fx.yearSeries(y);
      }
      double? fxOn(DateTime d) {
        final v = FxService.lookup(series[d.year] ?? const {}, d);
        // Primeros días de enero: puede estar en la serie del año anterior.
        return v ?? FxService.lookup(series[d.year - 1] ?? const {}, d);
      }

      _report = TaxCalculator.build(year: _year, activities: acts, fxOn: fxOn);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export() async {
    final r = _report;
    if (r == null) return;
    try {
      final fileName = 'reporte_inversiones_${r.year}.csv';
      if (kIsWeb) {
        await downloadTextFile(fileName, '﻿${r.toCsv()}', mimeType: 'text/csv');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/reporte_inversiones_${r.year}.csv');
      // BOM para que Excel respete tildes y ñ.
      await file.writeAsString('﻿${r.toCsv()}');
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Reporte de inversiones ${r.year}',
        text: 'Reporte referencial de ganancias y dividendos ${r.year}',
      ));
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo exportar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final r = _report;
    final nowYear = DateTime.now().year;
    final dateFmt = DateFormat('d MMM', 'es');
    String clpOr(double v, bool missing) => missing && v == 0 ? '—' : Fmt.clp(v, hidden: provider.hideBalances);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte SII'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: r == null ? null : _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var y = nowYear; y >= nowYear - 4; y--)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$y'),
                      selected: _year == y,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _year = y);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            'Cálculo referencial: costo de venta por método FIFO y conversión a pesos con el dólar '
            'observado de cada fecha. Revisa con un contador antes de declarar en el F22.',
            icon: Icons.gavel_rounded,
          ),
          const Wrap(
            spacing: 12,
            children: [
              HelpLink('impuestos', text: '¿Qué tengo que declarar?'),
              HelpLink('dividendo', text: '¿Qué es la retención?'),
              HelpLink('fifo', text: '¿Qué es FIFO?'),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'No se pudo generar',
              message: _error!,
              actionLabel: 'Reintentar',
              onAction: _load,
            )
          else if (r != null) ...[
            if (r.missingFx)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: InfoBanner(
                  'Faltó el dólar observado de algunas fechas; los totales en pesos pueden estar incompletos.',
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatGrid(items: [
                  ('Resultado ventas (US\$)', provider.moneySigned(r.totalGainUsd)),
                  ('Resultado ventas (CLP)', clpOr(r.totalGainClp, r.missingFx)),
                  ('Dividendos brutos (US\$)', provider.money(r.totalDividendsUsd)),
                  ('Dividendos brutos (CLP)', clpOr(r.totalDividendsClp, r.missingFx)),
                  ('Retenido EE.UU. (US\$)', provider.money(r.totalWithheldUsd)),
                  ('Retenido EE.UU. (CLP)', clpOr(r.totalWithheldClp, r.missingFx)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El impuesto retenido en EE.UU. sobre dividendos podría usarse como crédito '
              'por impuestos pagados en el extranjero, según tu situación tributaria.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SectionTitle('Ventas ${r.year} (${r.sales.length})'),
            if (r.sales.isEmpty)
              Text('Sin ventas este año.', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ...r.sales.map((s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${s.symbol} · ${Fmt.qty(s.qty)} acc.',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${dateFmt.format(s.date)} · venta ${provider.money(s.proceedsUsd)} · '
                        'costo ${provider.money(s.costUsd)}'
                        '${s.gainClp != null ? "\nResultado CLP: ${Fmt.clp(s.gainClp!, hidden: provider.hideBalances)}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: s.gainClp != null,
                      trailing: Text(
                        provider.moneySigned(s.gainUsd),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: s.gainUsd >= 0 ? AppTheme.up : AppTheme.down,
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 24),
            SectionTitle('Dividendos ${r.year} (${r.dividends.length})'),
            if (r.dividends.isEmpty)
              Text('Sin dividendos este año.', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ...r.dividends.map((d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(d.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${dateFmt.format(d.date)} · retenido ${provider.money(d.withheldUsd)}'
                        '${d.fx != null ? " · dólar ${Fmt.clp(d.fx!)}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(provider.money(d.grossUsd),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  )),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Exportar a CSV (Excel)'),
            ),
          ],
        ],
      ),
    );
  }
}
