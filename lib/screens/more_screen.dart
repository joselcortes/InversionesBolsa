import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_catalog.dart';
import '../providers/portfolio_provider.dart';
import '../services/update_service.dart';
import 'activity_screen.dart';
import 'dca_screen.dart';
import 'learn_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';
import 'tax_report_screen.dart';

/// Menú con el resto de las secciones, cada una con una frase que explica
/// para qué sirve.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;

    Widget item(IconData icon, Color color, String title, String subtitle, Widget page,
            {bool needsAccount = false}) =>
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            enabled: !needsAccount || provider.isConfigured,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          item(Icons.school_rounded, Colors.amber, 'Aprende',
              'Qué significa cada cosa, explicado simple', const LearnScreen()),
          item(Icons.newspaper_rounded, scheme.primary, 'Noticias',
              'Lo que se dice de tus acciones y del mercado', const NewsScreen(),
              needsAccount: true),
          item(Icons.autorenew_rounded, Colors.teal, 'Compras automáticas',
              'Invierte un monto fijo cada semana o mes', const DcaScreen(),
              needsAccount: true),
          item(Icons.receipt_long_rounded, Colors.purple, 'Historial',
              'Todas tus compras, ventas y dividendos', const ActivityScreen(),
              needsAccount: true),
          item(Icons.gavel_rounded, Colors.orange, 'Reporte para el SII',
              'Tus ganancias y dividendos del año, en pesos', const TaxReportScreen(),
              needsAccount: true),
          item(Icons.settings_rounded, scheme.onSurfaceVariant, 'Ajustes',
              'Cuenta, moneda, seguridad y notificaciones', const SettingsScreen()),
          ValueListenableBuilder<StoreRelease?>(
            valueListenable: UpdateService.available,
            builder: (context, update, _) => Badge(
              isLabelVisible: update != null,
              label: const Text('Nuevo'),
              alignment: const AlignmentDirectional(0.92, -0.6),
              child: item(
                Icons.storefront_rounded,
                Colors.green,
                'Mi tienda',
                update != null
                    ? 'Hay una versión nueva (${update.version}) lista para instalar'
                    : 'Actualizaciones de tus apps',
                const StoreScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
