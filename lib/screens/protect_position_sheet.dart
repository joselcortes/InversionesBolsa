import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/position.dart';
import '../providers/portfolio_provider.dart';
import '../services/alpaca_service.dart';
import '../services/auth_gate_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';

enum _Protection { stopLoss, trailing, oco }

/// Programa en el bróker una venta automática para una posición que ya
/// tienes: stop-loss fijo, trailing stop (%) o take-profit + stop-loss (OCO).
Future<void> showProtectPositionSheet(BuildContext context, Position position) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProtectSheet(position: position),
  );
}

class _ProtectSheet extends StatefulWidget {
  final Position position;
  const _ProtectSheet({required this.position});

  @override
  State<_ProtectSheet> createState() => _ProtectSheetState();
}

class _ProtectSheetState extends State<_ProtectSheet> {
  _Protection _kind = _Protection.trailing;
  late final TextEditingController _qtyCtrl;
  final _stopCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _trailCtrl = TextEditingController(text: '8');
  bool _submitting = false;

  Position get p => widget.position;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: Fmt.qty(p.qtyAvailable.floorToDouble()));
    _stopCtrl.text = Fmt.number(p.currentPrice * 0.92);
    _tpCtrl.text = Fmt.number(p.currentPrice * 1.15);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _stopCtrl.dispose();
    _tpCtrl.dispose();
    _trailCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final qty = Fmt.parse(_qtyCtrl.text);
    if (qty == null || qty <= 0) return 'Ingresa una cantidad válida';
    if (qty != qty.roundToDouble()) return 'Estas órdenes requieren acciones enteras';
    if (qty > p.qtyAvailable + 1e-9) {
      return 'Solo tienes ${Fmt.qty(p.qtyAvailable)} acciones libres '
          '(el resto ya está en otras órdenes)';
    }
    switch (_kind) {
      case _Protection.stopLoss:
        final s = Fmt.parse(_stopCtrl.text);
        if (s == null || s <= 0) return 'Ingresa el precio de stop';
        if (s >= p.currentPrice) return 'El stop debe ser menor al precio actual';
      case _Protection.trailing:
        final t = Fmt.parse(_trailCtrl.text);
        if (t == null || t <= 0 || t >= 50) return 'El % debe estar entre 0 y 50';
      case _Protection.oco:
        final s = Fmt.parse(_stopCtrl.text);
        final tp = Fmt.parse(_tpCtrl.text);
        if (s == null || tp == null) return 'Ingresa ambos precios';
        if (s >= p.currentPrice) return 'El stop-loss debe ser menor al precio actual';
        if (tp <= p.currentPrice) return 'El take-profit debe ser mayor al precio actual';
    }
    return null;
  }

  String _summary() {
    final qty = Fmt.parse(_qtyCtrl.text) ?? 0;
    final q = Fmt.qty(qty);
    return switch (_kind) {
      _Protection.stopLoss =>
        'Vender $q ${p.symbol} si el precio baja a ${Fmt.usd(Fmt.parse(_stopCtrl.text) ?? 0)}.',
      _Protection.trailing =>
        'Vender $q ${p.symbol} si el precio cae ${_trailCtrl.text}% desde su máximo '
            '(el stop sube solo cuando la acción sube).',
      _Protection.oco =>
        'Vender $q ${p.symbol} si sube a ${Fmt.usd(Fmt.parse(_tpCtrl.text) ?? 0)} '
            'o si baja a ${Fmt.usd(Fmt.parse(_stopCtrl.text) ?? 0)} (la primera que ocurra cancela la otra).',
    };
  }

  Future<void> _submit() async {
    final provider = context.read<PortfolioProvider>();
    final err = _validate();
    if (err != null) {
      showSnack(context, err);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Programar venta automática',
      message: '${_summary()}\n\nQueda activa en Alpaca hasta que se ejecute o la canceles.'
          '${provider.isLive ? "\n\n⚠️ Modo REAL." : ""}',
      confirmLabel: 'Programar',
    );
    if (!ok || !mounted) return;
    setState(() => _submitting = true);
    final auth = await AuthGateService().confirmIdentity(
      reason: 'Confirma para programar la venta',
      strict: provider.isLive,
    );
    if (!mounted) return;
    if (auth != AuthResult.ok) {
      setState(() => _submitting = false);
      showSnack(context, AuthGateService.failureMessage(auth));
      return;
    }
    try {
      final qty = Fmt.parse(_qtyCtrl.text)!;
      final service = provider.requireService();
      switch (_kind) {
        case _Protection.stopLoss:
          await service.placeOrder(
            symbol: p.symbol,
            side: 'sell',
            qty: qty,
            type: 'stop',
            stopPrice: Fmt.parse(_stopCtrl.text),
          );
        case _Protection.trailing:
          await service.placeOrder(
            symbol: p.symbol,
            side: 'sell',
            qty: qty,
            type: 'trailing_stop',
            trailPercent: Fmt.parse(_trailCtrl.text),
          );
        case _Protection.oco:
          await service.placeOrder(
            symbol: p.symbol,
            side: 'sell',
            qty: qty,
            takeProfitPrice: Fmt.parse(_tpCtrl.text),
            stopLossPrice: Fmt.parse(_stopCtrl.text),
          );
      }
      await provider.refreshAll();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Venta automática programada ✅')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnack(context, 'Error: ${e is AlpacaException ? e.message : e}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validation = _validate();
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
            Text('Proteger ${p.symbol}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Precio actual ${Fmt.usd(p.currentPrice)} · costo promedio ${Fmt.usd(p.avgEntryPrice)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_Protection>(
              segments: const [
                ButtonSegment(value: _Protection.trailing, label: Text('Trailing')),
                ButtonSegment(value: _Protection.stopLoss, label: Text('Stop-loss')),
                ButtonSegment(value: _Protection.oco, label: Text('SL + TP')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_kind) {
                _Protection.trailing =>
                  'Sigue a la acción cuando sube y la vende si cae cierto % desde su punto más alto. '
                      'Ideal para asegurar ganancias.',
                _Protection.stopLoss => 'La vende si el precio baja hasta el valor que elijas. '
                    'Limita cuánto puedes perder.',
                _Protection.oco => 'Pones una meta de ganancia y una pérdida máxima. '
                    'La primera que ocurra vende la acción.',
              },
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            HelpLink(switch (_kind) {
              _Protection.trailing => 'trailing',
              _Protection.stopLoss => 'stop_loss',
              _Protection.oco => 'bracket',
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Acciones a proteger (libres: ${Fmt.qty(p.qtyAvailable)})',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_kind == _Protection.trailing)
              TextField(
                controller: _trailCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Vender si cae este % desde el máximo'),
                onChanged: (_) => setState(() {}),
              ),
            if (_kind != _Protection.trailing)
              TextField(
                controller: _stopCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Stop-loss (US\$) — vender si baja a'),
                onChanged: (_) => setState(() {}),
              ),
            if (_kind == _Protection.oco) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _tpCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Take-profit (US\$) — vender si sube a'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            InfoBanner(validation ?? _summary(),
                icon: validation == null ? Icons.shield_outlined : Icons.error_outline_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                onPressed: _submitting || validation != null ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Programar venta automática'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
