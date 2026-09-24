import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset_info.dart';
import '../providers/portfolio_provider.dart';

/// Buscador de acciones por símbolo o nombre de empresa. Devuelve el
/// símbolo elegido.
Future<String?> showSymbolSearch(BuildContext context, {String title = 'Buscar acción'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SymbolSearchSheet(title: title),
  );
}

class _SymbolSearchSheet extends StatefulWidget {
  final String title;
  const _SymbolSearchSheet({required this.title});

  @override
  State<_SymbolSearchSheet> createState() => _SymbolSearchSheetState();
}

class _SymbolSearchSheetState extends State<_SymbolSearchSheet> {
  final _ctrl = TextEditingController();
  List<AssetInfo> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _loading = true);
      final r = await context.read<PortfolioProvider>().searchAssets(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typed = _ctrl.text.trim().toUpperCase();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Ej: AAPL, Apple, Coca-Cola',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (v) {
                      if (_results.isNotEmpty) {
                        Navigator.pop(context, _results.first.symbol);
                      } else if (v.trim().isNotEmpty) {
                        Navigator.pop(context, v.trim().toUpperCase());
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            typed.isEmpty
                                ? 'Escribe el símbolo o parte del nombre de la empresa.'
                                : _loading
                                    ? 'Buscando…'
                                    : 'Sin resultados en la lista de Alpaca.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          if (typed.isNotEmpty && !_loading) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context, typed),
                              child: Text('Usar "$typed" igual'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final a = _results[i];
                        return ListTile(
                          title: Text(a.symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            a.fractionable ? '${a.exchange} · fracc.' : a.exchange,
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                          onTap: () => Navigator.pop(context, a.symbol),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
