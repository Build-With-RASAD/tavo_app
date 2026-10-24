/// One order as shown on the restaurant panel's order cards.
///
/// Tolerant of missing keys: strings default to `''`, numbers to `0`.
/// Customer identity prefers a populated `userId` block and falls back to
/// the `customer` block when `userId` is absent or empty.
class PanelOrder {
  const PanelOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.totalPrice,
    required this.paymentStatus,
    required this.orderStatus,
    required this.createdAt,
    this.tableCode = '',
    this.zone = '',
    this.source = '',
    this.sessionCode = '',
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String customerPhone;
  final List<OrderLine> items;
  final double subtotal;
  final double tax;
  final double totalPrice;
  final String paymentStatus;
  final String orderStatus;
  final String createdAt;

  /// Table code for dine-in orders (`A12`); empty for delivery/pickup.
  final String tableCode;

  /// Table zone (`Terrace`); empty when the table has no zone.
  final String zone;

  /// `app`, `qr_table`, `counter` or `waiter`.
  final String source;

  /// The party code (`A12-1`) for QR table orders.
  final String sessionCode;

  bool get isTableOrder => source == 'qr_table' || tableCode.isNotEmpty;

  DateTime? get placedAt => DateTime.tryParse(createdAt);

  /// Whole minutes since the order was placed, for kitchen timers.
  int minutesWaiting([DateTime? now]) {
    final placed = placedAt;
    if (placed == null) return 0;
    final minutes = (now ?? DateTime.now()).difference(placed).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  factory PanelOrder.fromJson(Map<String, dynamic> json) {
    final userId = _asMap(json['userId']);
    final customer = _asMap(json['customer']);
    final rawItems = json['menuItems'] ?? json['items'];

    return PanelOrder(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName:
          _firstNonEmpty(userId?['name'], customer?['name']),
      customerPhone:
          _firstNonEmpty(userId?['phone'], customer?['phone']),
      items: rawItems is List
          ? rawItems
              .map((e) =>
                  OrderLine.fromJson(_asMap(e) ?? const <String, dynamic>{}))
              .toList()
          : const [],
      subtotal: _toDouble(json['subtotal']),
      tax: _toDouble(json['tax']),
      totalPrice: _toDouble(json['totalPrice'] ?? json['totalAmount']),
      paymentStatus: json['paymentStatus']?.toString() ?? '',
      orderStatus: json['orderStatus']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      tableCode: _asMap(json['tableId'])?['code']?.toString() ?? '',
      zone: _asMap(json['tableId'])?['zone']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sessionCode: _asMap(json['sessionId'])?['code']?.toString() ?? '',
    );
  }
}

/// One line of an order (`menuItems` entry); specifications and image are
/// intentionally out of scope for order cards.
class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      name: json['name']?.toString() ?? '',
      quantity: _toInt(json['quantity']),
      unitPrice: _toDouble(json['unitPrice']),
      lineTotal: _toDouble(json['lineTotal']),
    );
  }
}

/// i18n key for an order status label — the key is the status itself.
String orderStatusLabelKey(String orderStatus) => orderStatus;

/// Valid next statuses for an order, mirroring the backend `validTransitions`
/// map. Terminal statuses (`served`, `cancelled`) have no next actions.
const Map<String, List<String>> _validTransitions = {
  'pending': ['confirmed', 'cancelled'],
  'confirmed': ['preparing', 'cancelled'],
  'preparing': ['ready', 'cancelled'],
  'ready': ['served', 'cancelled'],
};

List<String> nextOrderActionsFor(String status) =>
    _validTransitions[status] ?? const [];

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

String _firstNonEmpty(Object? primary, Object? fallback) {
  final first = primary?.toString() ?? '';
  if (first.isNotEmpty) return first;
  return fallback?.toString() ?? '';
}

int _toInt(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}') ?? 0;

double _toDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? ''}') ?? 0;
