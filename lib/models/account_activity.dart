/// Movimiento de la cuenta (`/v2/account/activities`): ejecuciones de
/// órdenes (FILL), dividendos (DIV), retenciones (DIVNRA), comisiones, etc.
class AccountActivity {
  final String id;
  final String type;
  final DateTime date;
  final String? symbol;
  final String? side;
  final double? qty;
  final double? price;
  final double? netAmount;
  final String? description;

  const AccountActivity({
    required this.id,
    required this.type,
    required this.date,
    this.symbol,
    this.side,
    this.qty,
    this.price,
    this.netAmount,
    this.description,
  });

  bool get isFill => type == 'FILL';

  bool get isDividend => type.startsWith('DIV') && type != 'DIVNRA';

  /// Retención de impuesto a no residentes sobre dividendos (EE.UU.).
  bool get isWithholding => type == 'DIVNRA';

  /// Monto en US$ con signo (+ entra plata, − sale).
  double get cashFlow {
    if (isFill) {
      final gross = (qty ?? 0) * (price ?? 0);
      return side == 'buy' ? -gross : gross;
    }
    return netAmount ?? 0;
  }

  String get typeLabel => switch (type) {
        'FILL' => side == 'buy' ? 'Compra' : 'Venta',
        'DIV' || 'DIVCGL' || 'DIVCGS' || 'DIVROC' || 'DIVTXEX' => 'Dividendo',
        'DIVNRA' => 'Retención EE.UU.',
        'FEE' => 'Comisión',
        'CSD' => 'Depósito',
        'CSW' => 'Retiro',
        'INT' => 'Intereses',
        'JNLC' || 'JNLS' => 'Transferencia',
        'SPLIT' => 'Split',
        'MA' => 'Fusión/adquisición',
        _ => type,
      };

  static double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory AccountActivity.fromJson(Map<String, dynamic> json) {
    final dateStr = (json['transaction_time'] ?? json['date']) as String? ?? '';
    return AccountActivity(
      id: json['id'] as String? ?? '',
      type: json['activity_type'] as String? ?? '',
      date: DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now(),
      symbol: json['symbol'] as String?,
      side: json['side'] as String?,
      qty: _d(json['qty']),
      price: _d(json['price']),
      netAmount: _d(json['net_amount']),
      description: json['description'] as String?,
    );
  }
}
