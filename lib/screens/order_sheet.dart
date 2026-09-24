import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/alpaca_service.dart';
import '../services/auth_gate_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/friendly_widgets.dart';

Future<void> showOrderSheet(
  BuildContext context, {
  required String symbol,
  required String side, // 'buy' | 'sell'
  required Quote? quote,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => OrderSheet(symbol: symbol, side: side, quote: quote),
  );
}

enum _AmountMode { shares, dollars }

enum _OrderKind { market, limit }

class OrderSheet extends StatefulWidget {
  final String symbol;
  final String side;
  final Quote? quote;

  const OrderSheet({
    super.key,
    required this.symbol,
    required this.side,
    required this.quote,
  });

  @override
  State<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<OrderSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _dollarsCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _takeProfitCtrl = TextEditingController();
  final _stopLossCtrl = TextEditingController();
  final _authGate = AuthGateService();
  bool _submitting = false;
  bool _useBracket = false;
  _AmountMode _mode = _AmountMode.shares;
  _OrderKind _kind = _OrderKind.market;

  bool get _isBuy => widget.side == 'buy';

  @override
  void initState() {
    super.initState();
    final price = widget.quote?.price;
    if (price != null) _limitCtrl.text = formatPrice(price).replaceAll('.', ',');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _dollarsCtrl.dispose();
    _limitCtrl.dispose();
    _takeProfitCtrl.dispose();
    _stopLossCtrl.dispose();
    super.dispose();
  }

  double? get _qty => Fmt.parse(_qtyCtrl.text);
  double? get _dollars => Fmt.parse(_dollarsCtrl.text);
  double? get _limit => Fmt.parse(_limitCtrl.text);

  /// Precio de referencia: el límite si es orden límite, si no el actual.
  double? get _refPrice => _kind == _OrderKind.limit ? _limit : widget.quote?.price;

  double? get _estimatedTotal {
    if (_mode == _AmountMode.dollars) return _dollars;
    final qty = _qty;
    final price = _refPrice;
    if (qty == null || price == null) return null;
    return qty * price;
  }

  double? get _estimatedShares {
    if (_mode == _AmountMode.shares) return _qty;
    final d = _dollars;
    final price = _refPrice;
    if (d == null || price == null || price == 0) return null;
    return d / price;
  }

  /// Devuelve el mensaje de error o null si todo está bien.
  String? _validate(PortfolioProvider provider) {
    final price = widget.quote?.price;
    if (_kind == _OrderKind.limit && (_limit == null || _limit! <= 0)) {
      return 'Ingresa un precio límite válido';
    }
    if (_mode == _AmountMode.shares) {
      final qty = _qty;
      if (qty == null || qty <= 0) return 'Ingresa una cantidad válida';
      final fractional = qty != qty.roundToDouble();
      final asset = provider.assetInfo(widget.symbol);
      if (fractional && asset != null && !asset.fractionable) {
        return '${widget.symbol} no permite acciones fraccionadas';
      }
      if (fractional && _kind == _OrderKind.limit) {
        return 'Las órdenes límite requieren acciones enteras';
      }
    } else {
      final d = _dollars;
      if (d == null || d < 1) return 'El monto mínimo es US\$1';
    }

    if (!_isBuy) {
      final pos = provider.positionFor(widget.symbol);
      if (pos == null) return 'No tienes acciones de ${widget.symbol} para vender';
      final shares = _estimatedShares;
      if (shares != null && shares > pos.qtyAvailable + 1e-9) {
        final locked = pos.qty - pos.qtyAvailable;
        return 'Solo tienes ${Fmt.qty(pos.qtyAvailable)} disponibles'
            '${locked > 0 ? " (${Fmt.qty(locked)} comprometidas en otras órdenes)" : ""}';
      }
    } else {
      final total = _estimatedTotal;
      final bp = provider.account?.buyingPower;
      if (total != null && bp != null && total > bp) {
        return 'Poder de compra insuficiente (${Fmt.usd(bp)})';
      }
    }

    if (_isBuy && _useBracket) {
      if (_mode == _AmountMode.dollars || (_qty != null && _qty != _qty!.roundToDouble())) {
        return 'Stop-loss/take-profit automáticos requieren acciones enteras';
      }
      final tp = Fmt.parse(_takeProfitCtrl.text);
      final sl = Fmt.parse(_stopLossCtrl.text);
      if (tp == null && sl == null) {
        return 'Ingresa al menos un precio de take-profit o stop-loss';
      }
      final ref = _refPrice ?? price;
      if (ref == null) return 'Espera a que cargue el precio actual';
      if (tp != null && tp <= ref) return 'El take-profit debe ser mayor a ${Fmt.usd(ref)}';
      if (sl != null && sl >= ref) return 'El stop-loss debe ser menor a ${Fmt.usd(ref)}';
    }
    return null;
  }

  Future<void> _confirmAndSubmit() async {
    final provider = context.read<PortfolioProvider>();
    final err = _validate(provider);
    if (err != null) {
      showSnack(context, err);
      return;
    }

    final total = _estimatedTotal;
    final takeProfit = _isBuy && _useBracket ? Fmt.parse(_takeProfitCtrl.text) : null;
    final stopLoss = _isBuy && _useBracket ? Fmt.parse(_stopLossCtrl.text) : null;
    final closed = provider.clock != null && !provider.clock!.isOpen;
    final amountText = _mode == _AmountMode.shares
        ? '${Fmt.qty(_qty!)} acción(es)'
        : '${Fmt.usd(_dollars!)} en acciones';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isBuy ? 'Confirmar compra' : 'Confirmar venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_isBuy ? "Comprar" : "Vender"} $amountText de ${widget.symbol}'),
            const SizedBox(height: 4),
            Text(_kind == _OrderKind.limit
                ? 'Orden límite a ${Fmt.usd(_limit!)} (válida hasta cancelarla)'
                : 'Orden a mercado (precio del momento)'),
            if (total != null) ...[
              const SizedBox(height: 8),
              Text('Total estimado: ${Fmt.usd(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (provider.clp(total) != null)
                Text(provider.clp(total)!, style: const TextStyle(fontSize: 12)),
            ],
            if (takeProfit != null) ...[
              const SizedBox(height: 4),
              Text('Vender automáticamente si sube a ${Fmt.usd(takeProfit)} (take-profit)'),
            ],
            if (stopLoss != null) ...[
              const SizedBox(height: 4),
              Text('Vender automáticamente si baja a ${Fmt.usd(stopLoss)} (stop-loss)'),
            ],
            if (closed) ...[
              const SizedBox(height: 8),
              const Text('🕒 El mercado está cerrado: la orden quedará pendiente hasta la apertura.',
                  style: TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text(
              provider.isLive
                  ? '⚠️ Modo REAL: esto usará tu dinero de verdad y no se puede deshacer.'
                  : 'Modo paper: esto es una simulación, no usa dinero real.',
              style: TextStyle(
                color: provider.isLive ? Colors.red : Colors.grey,
                fontSize: 12,
                fontWeight: provider.isLive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isBuy ? 'Confirmar compra' : 'Confirmar venta'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final auth = await _authGate.confirmIdentity(
      reason: _isBuy ? 'Confirma tu identidad para comprar' : 'Confirma tu identidad para vender',
      strict: provider.isLive,
    );
    if (!mounted) return;
    if (auth != AuthResult.ok) {
      setState(() => _submitting = false);
      showSnack(context, '${AuthGateService.failureMessage(auth)} Orden no enviada.');
      return;
    }
    try {
      final order = await provider.requireService().placeOrder(
            symbol: widget.symbol,
            side: widget.side,
            qty: _mode == _AmountMode.shares ? _qty : null,
            notional: _mode == _AmountMode.dollars ? _dollars : null,
            type: _kind == _OrderKind.limit ? 'limit' : 'market',
            limitPrice: _kind == _OrderKind.limit ? _limit : null,
            takeProfitPrice: takeProfit,
            stopLossPrice: stopLoss,
          );
      await provider.refreshAll();
      if (!mounted) return;
      // Capturamos el messenger ANTES de cerrar la hoja: usar `context`
      // después de pop() puede apuntar a un árbol ya desmontado.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            'Orden enviada: ${_isBuy ? "compra" : "venta"} de ${widget.symbol} · '
            'Estado: ${order.statusLabel}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showSnack(context, 'Error al enviar la orden: ${e is AlpacaException ? e.message : e}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final scheme = Theme.of(context).colorScheme;
    final pos = provider.positionFor(widget.symbol);
    final asset = provider.assetInfo(widget.symbol);
    final fractionable = asset?.fractionable ?? true;
    final total = _estimatedTotal;
    final shares = _estimatedShares;
    final validation = _validate(provider);

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_isBuy ? "Comprar" : "Vender"} ${widget.symbol}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (widget.quote != null)
              Text('Precio actual: ${Fmt.usd(widget.quote!.price)}',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            if (_isBuy && provider.account != null)
              Text('Poder de compra: ${provider.money(provider.account!.buyingPower)}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            if (!_isBuy && pos != null)
              Text(
                'Tienes ${Fmt.qty(pos.qty)} · disponibles para vender ${Fmt.qty(pos.qtyAvailable)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            const SizedBox(height: 16),
            SegmentedButton<_OrderKind>(
              segments: const [
                ButtonSegment(value: _OrderKind.market, label: Text('A mercado')),
                ButtonSegment(value: _OrderKind.limit, label: Text('Límite')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                if (_kind == _OrderKind.limit) _mode = _AmountMode.shares;
              }),
            ),
            Text(
              _kind == _OrderKind.market
                  ? 'Se ${_isBuy ? "compra" : "vende"} ahora, al precio del momento.'
                  : 'Solo se ${_isBuy ? "compra" : "vende"} si el precio llega al que tú elijas.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            HelpLink(_kind == _OrderKind.market ? 'orden_mercado' : 'orden_limite'),
            if (_kind == _OrderKind.limit) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _isBuy
                      ? 'Precio límite (US\$) — comprar a este precio o menos'
                      : 'Precio límite (US\$) — vender a este precio o más',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            if (_kind == _OrderKind.market && fractionable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<_AmountMode>(
                  segments: const [
                    ButtonSegment(value: _AmountMode.shares, label: Text('Acciones')),
                    ButtonSegment(value: _AmountMode.dollars, label: Text('Monto US\$')),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    if (_mode == _AmountMode.dollars) _useBracket = false;
                  }),
                ),
              ),
            if (_mode == _AmountMode.shares)
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: fractionable
                      ? 'Cantidad de acciones (acepta decimales)'
                      : 'Cantidad de acciones',
                  suffixIcon: !_isBuy && pos != null
                      ? TextButton(
                          onPressed: () => setState(
                              () => _qtyCtrl.text = Fmt.qty(pos.qtyAvailable)),
                          child: const Text('Todo'),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              TextField(
                controller: _dollarsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto a invertir (US\$)'),
                onChanged: (_) => setState(() {}),
              ),
            if (_kind == _OrderKind.market && fractionable)
              const HelpLink('fraccionadas', text: '¿Qué es comprar por monto?'),
            const SizedBox(height: 8),
            if (total != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isBuy ? AppTheme.up : AppTheme.down).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isBuy ? 'Vas a pagar aprox.' : 'Vas a recibir aprox.',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Text(
                      provider.clp(total) != null
                          ? '${Fmt.clp(total * provider.usdClp!)} pesos'
                          : Fmt.usd(total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [
                        if (provider.clp(total) != null) Fmt.usd(total),
                        if (_mode == _AmountMode.dollars && shares != null)
                          '≈ ${Fmt.qty(double.parse(shares.toStringAsFixed(4)))} acciones',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            if (_isBuy && _mode == _AmountMode.shares) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Row(
                  children: [
                    Flexible(child: Text('Vender automático (stop-loss / take-profit)')),
                    InfoTip('bracket'),
                  ],
                ),
                subtitle: Text(
                  'Se vende sola si sube a tu meta de ganancia o baja a tu pérdida máxima, aunque la app esté cerrada.',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                value: _useBracket,
                onChanged: (v) => setState(() => _useBracket = v),
              ),
              if (_useBracket) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _takeProfitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Take-profit (US\$) — vender si sube a'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _stopLossCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Stop-loss (US\$) — vender si baja a'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            if (validation != null) ...[
              const SizedBox(height: 10),
              Text(validation, style: const TextStyle(color: AppTheme.down, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
                onPressed: _submitting || validation != null ? null : _confirmAndSubmit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isBuy ? 'Comprar' : 'Vender'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
