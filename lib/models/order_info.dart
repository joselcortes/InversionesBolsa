class OrderInfo {
  final String id;
  final String? clientOrderId;
  final String symbol;
  final String side;
  final String status;
  final String type;
  final String orderClass;
  final double? qty;
  final double? notional;
  final double? filledQty;
  final double? filledAvgPrice;
  final double? limitPrice;
  final double? stopPrice;
  final double? trailPercent;
  final DateTime createdAt;
  final DateTime? filledAt;
  final DateTime? updatedAt;
  final List<OrderInfo> legs;

  const OrderInfo({
    required this.id,
    this.clientOrderId,
    required this.symbol,
    required this.side,
    required this.status,
    this.type = 'market',
    this.orderClass = 'simple',
    required this.qty,
    this.notional,
    required this.filledQty,
    required this.filledAvgPrice,
    this.limitPrice,
    this.stopPrice,
    this.trailPercent,
    required this.createdAt,
    this.filledAt,
    this.updatedAt,
    this.legs = const [],
  });

  static const _openStatuses = {
    'new',
    'accepted',
    'pending_new',
    'partially_filled',
    'held',
    'accepted_for_bidding',
    'pending_replace',
    'calculated',
  };

  /// Orden todavía viva en el bróker (se puede cancelar).
  bool get isOpen => _openStatuses.contains(status);

  bool get isBuy => side == 'buy';

  String get statusLabel => switch (status) {
        'filled' => 'Ejecutada',
        'partially_filled' => 'Ejecutada parcialmente',
        'canceled' => 'Cancelada',
        'expired' => 'Expirada',
        'rejected' => 'Rechazada',
        'held' => 'En espera (condicional)',
        'pending_cancel' => 'Cancelando…',
        'pending_new' || 'accepted' || 'new' => 'Pendiente (esperando mercado)',
        _ => status,
      };

  String get typeLabel => switch (type) {
        'market' => 'Mercado',
        'limit' => 'Límite',
        'stop' => 'Stop',
        'stop_limit' => 'Stop límite',
        'trailing_stop' => 'Trailing stop',
        _ => type,
      };

  String get classLabel => switch (orderClass) {
        'bracket' => ' · con SL/TP',
        'oco' => ' · OCO',
        'oto' => ' · OTO',
        _ => '',
      };

  static double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory OrderInfo.fromJson(Map<String, dynamic> json) => OrderInfo(
        id: json['id'] as String,
        clientOrderId: json['client_order_id'] as String?,
        symbol: json['symbol'] as String? ?? '',
        side: json['side'] as String? ?? 'buy',
        status: json['status'] as String? ?? '',
        type: json['type'] as String? ?? json['order_type'] as String? ?? 'market',
        orderClass: (json['order_class'] as String?)?.isNotEmpty == true
            ? json['order_class'] as String
            : 'simple',
        qty: _d(json['qty']),
        notional: _d(json['notional']),
        filledQty: _d(json['filled_qty']),
        filledAvgPrice: _d(json['filled_avg_price']),
        limitPrice: _d(json['limit_price']),
        stopPrice: _d(json['stop_price']),
        trailPercent: _d(json['trail_percent']),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        filledAt: DateTime.tryParse(json['filled_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        legs: ((json['legs'] as List?) ?? const [])
            .map((e) => OrderInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
