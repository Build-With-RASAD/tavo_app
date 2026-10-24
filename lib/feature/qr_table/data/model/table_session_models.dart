// lib/feature/qr_table/data/model/table_session_models.dart
//
// Wire models for the QR table experience. Every parser is defensive: the
// guest's phone must render a table even if the backend adds, renames or drops
// an optional field — a thrown cast here would blank the whole screen.
double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _toText(dynamic value) => value == null ? '' : '$value';

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> _toList(dynamic value) => value is List ? value : const [];

/// What a scanned table card resolves to, before the guest joins.
class TableContext {
  const TableContext({
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantNameAr,
    required this.slug,
    required this.logoUrl,
    required this.tableId,
    required this.tableCode,
    required this.zone,
    required this.seats,
    required this.hasActiveSession,
    required this.guestCount,
  });

  final String restaurantId;
  final String restaurantName;
  final String restaurantNameAr;
  final String slug;
  final String logoUrl;
  final String tableId;
  final String tableCode;
  final String zone;
  final int seats;
  final bool hasActiveSession;
  final int guestCount;

  factory TableContext.fromJson(Map<String, dynamic> json) {
    final restaurant = _toMap(json['restaurant']);
    final name = _toMap(restaurant['name']);
    final table = _toMap(json['table']);
    final session = json['session'];

    return TableContext(
      restaurantId: _toText(restaurant['id']),
      restaurantName: _toText(name['en']),
      restaurantNameAr: _toText(name['ar']),
      slug: _toText(restaurant['slug']),
      logoUrl: _toText(_toMap(restaurant['logo'])['imageUrl']),
      tableId: _toText(table['id']),
      tableCode: _toText(table['code']),
      zone: _toText(table['zone']),
      seats: _toInt(table['seats']),
      hasActiveSession: session != null,
      guestCount: session == null ? 0 : _toInt(_toMap(session)['guestCount']),
    );
  }
}

/// The result of joining a table: the bearer token this phone must keep.
class JoinedTable {
  const JoinedTable({
    required this.guestToken,
    required this.label,
    required this.sessionId,
    required this.code,
  });

  final String guestToken;
  final String label;
  final String sessionId;
  final String code;

  factory JoinedTable.fromJson(Map<String, dynamic> json) {
    final session = _toMap(json['session']);
    final guest = _toMap(json['guest']);
    return JoinedTable(
      guestToken: _toText(json['guestToken']),
      label: _toText(guest['label']),
      sessionId: _toText(session['id']),
      code: _toText(session['code']),
    );
  }
}

class TableOrderLine {
  const TableOrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.specifications,
    required this.addedByGuestId,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<String> specifications;
  final String addedByGuestId;

  factory TableOrderLine.fromJson(Map<String, dynamic> json) => TableOrderLine(
        name: _toText(json['name']),
        quantity: _toInt(json['quantity']),
        unitPrice: _toDouble(json['unitPrice']),
        lineTotal: _toDouble(json['lineTotal']),
        specifications: _toList(json['specifications'])
            .map((spec) => _toText(_toMap(spec)['name']))
            .where((name) => name.isNotEmpty)
            .toList(growable: false),
        addedByGuestId: _toText(json['addedByGuestId']),
      );
}

class TableOrder {
  const TableOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.notes,
    required this.addedByMe,
    required this.placedAt,
  });

  final String id;
  final String orderNumber;
  final String status;
  final List<TableOrderLine> items;
  final double subtotal;
  final double tax;
  final double total;
  final String notes;
  final bool addedByMe;
  final DateTime? placedAt;

  bool get isActive => status != 'served' && status != 'cancelled';

  factory TableOrder.fromJson(Map<String, dynamic> json) => TableOrder(
        id: _toText(json['id']),
        orderNumber: _toText(json['orderNumber']),
        status: _toText(json['status']).isEmpty ? 'pending' : _toText(json['status']),
        items: _toList(json['items'])
            .map((item) => TableOrderLine.fromJson(_toMap(item)))
            .toList(growable: false),
        subtotal: _toDouble(json['subtotal']),
        tax: _toDouble(json['tax']),
        total: _toDouble(json['total']),
        notes: _toText(json['notes']),
        addedByMe: json['addedByMe'] == true,
        placedAt: DateTime.tryParse(_toText(json['placedAt'])),
      );
}

class TableBill {
  const TableBill({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paid,
    required this.currency,
  });

  final double subtotal;
  final double tax;
  final double total;
  final double paid;
  final String currency;

  static const TableBill empty =
      TableBill(subtotal: 0, tax: 0, total: 0, paid: 0, currency: 'SAR');

  factory TableBill.fromJson(Map<String, dynamic> json) => TableBill(
        subtotal: _toDouble(json['subtotal']),
        tax: _toDouble(json['tax']),
        total: _toDouble(json['total']),
        paid: _toDouble(json['paid']),
        currency: _toText(json['currency']).isEmpty
            ? 'SAR'
            : _toText(json['currency']),
      );
}

/// One party's live view: who is here, what was ordered, what is owed.
class TableSnapshot {
  const TableSnapshot({
    required this.sessionId,
    required this.code,
    required this.guestCount,
    required this.guests,
    required this.orders,
    required this.bill,
    required this.myLabel,
    required this.canOrder,
    required this.hasRated,
  });

  final String sessionId;
  final String code;
  final int guestCount;
  final List<String> guests;
  final List<TableOrder> orders;
  final TableBill bill;
  final String myLabel;
  final bool canOrder;
  final bool hasRated;

  factory TableSnapshot.fromJson(Map<String, dynamic> json) {
    final session = _toMap(json['session']);
    final me = _toMap(json['me']);

    return TableSnapshot(
      sessionId: _toText(session['id']),
      code: _toText(session['code']),
      guestCount: _toInt(session['guestCount']),
      guests: _toList(session['guests'])
          .map((guest) => _toText(_toMap(guest)['label']))
          .where((label) => label.isNotEmpty)
          .toList(growable: false),
      orders: _toList(json['orders'])
          .map((order) => TableOrder.fromJson(_toMap(order)))
          .toList(growable: false),
      bill: json['bill'] == null
          ? TableBill.empty
          : TableBill.fromJson(_toMap(json['bill'])),
      myLabel: _toText(me['label']),
      canOrder: me['canOrder'] != false,
      hasRated: me['hasRated'] == true,
    );
  }
}

/// One line the guest is about to send to the kitchen.
class TableCartLine {
  const TableCartLine({
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;

  TableCartLine copyWith({int? quantity}) => TableCartLine(
        menuItemId: menuItemId,
        name: name,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'menuItemId': menuItemId,
        'quantity': quantity,
      };
}

/// What the guest says about the visit.
class RatingDraft {
  const RatingDraft({
    required this.type,
    required this.scores,
    required this.comment,
    required this.waiterMessage,
  });

  /// `review`, `complaint` or `suggestion`.
  final String type;

  /// Area key (`restaurant`, `waiter`, `food`, `speed`, `cleanliness`) → 1..5.
  final Map<String, int> scores;
  final String comment;
  final String waiterMessage;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (scores.isNotEmpty) 'scores': scores,
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (waiterMessage.trim().isNotEmpty)
          'waiterMessage': waiterMessage.trim(),
      };
}
