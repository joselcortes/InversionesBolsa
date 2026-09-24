import 'package:flutter/material.dart';

import '../content/glossary.dart';
import '../widgets/friendly_widgets.dart';

/// Sección "Aprende": guía rápida de uso y explicación simple de cada
/// concepto, con buscador.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _steps = [
    ('🔑', 'Conecta tu cuenta', 'En Más → Ajustes pega tus claves de Alpaca. Empieza en modo práctica.', 'api_keys'),
    ('🏠', 'Mira tu resumen', 'En Inicio ves tu saldo en pesos, cuánto ganaste o perdiste hoy y en total.', 'saldo_total'),
    ('🔎', 'Busca acciones', 'En Mercado toca + y busca por nombre (ej: "Apple") para seguirlas.', 'accion'),
    ('🛒', 'Compra o vende', 'Entra a una acción y usa Comprar/Vender. Siempre te pedimos confirmar.', 'orden'),
    ('🛡️', 'Protege tu inversión', 'En una acción que tengas, toca "Proteger" para vender sola si cae mucho.', 'stop_loss'),
    ('🔔', 'Crea alertas', 'Te avisamos al celular si una acción llega al precio que quieres.', 'alertas'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _entryTile(GlossaryEntry e) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(e.short),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showTermSheet(context, e.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = Glossary.search(_query);

    return Scaffold(
      appBar: AppBar(title: const Text('Aprende')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Busca un concepto (ej: stop-loss, dividendo)',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (_query.isNotEmpty) ...[
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No encontramos "$_query".',
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else
              ...results.map(_entryTile),
          ] else ...[
            Text('Empieza aquí', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('Cómo usar la app en 6 pasos. Toca cada uno para saber más.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    child: Text(_steps[i].$1, style: const TextStyle(fontSize: 18)),
                  ),
                  title: Text('${i + 1}. ${_steps[i].$2}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_steps[i].$3),
                  onTap: () => showTermSheet(context, _steps[i].$4),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '💡 Consejo: en toda la app verás el ícono ⓘ junto a los términos difíciles. '
                'Tócalo y te explicamos qué significa.',
                style: TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Text('Diccionario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 8),
            for (final s in Glossary.sections)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  shape: const Border(),
                  leading: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.entries.length} conceptos'),
                  children: [
                    for (final e in s.entries)
                      ListTile(
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(e.short),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showTermSheet(context, e.id),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Esta app es una herramienta; no es asesoría financiera. Invertir tiene riesgos: '
              'el valor de tus acciones puede bajar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
