// lib/feature/panel_tables/data/model/table_models.dart
//
// Tolerant decoding: the panel API populates references and sends some labels
// as `{ar, en}` maps. A hard cast crashed the tables screen with
// "type 'Map<String, dynamic>' is not a subtype of type 'String'".
String _text(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    return (value['_id'] ?? value['id'] ?? value['code'] ?? '').toString();
  }
  return value.toString();
}

String _localized(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is! Map) return value.toString();
  return (value['ar'] ?? value['en'] ?? value['name'] ?? '').toString();
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

class PanelTableType {
  const PanelTableType({
    required this.id,
    required this.label,
    this.seatsPerTable = 0,
    this.tablesCount = 0,
  });

  final String id;
  final String label;
  final int seatsPerTable;
  final int tablesCount;

  factory PanelTableType.fromJson(Map<String, dynamic> json) => PanelTableType(
    id: _text(json['_id'] ?? json['id']),
    label: _localized(json['label']),
    seatsPerTable: _int(json['seatsPerTable']),
    tablesCount: _int(json['tablesCount']),
  );
}

/// One pending ask from the browser: the bill, the card machine, or a waiter.
class PanelServiceRequestSummary {
  const PanelServiceRequestSummary({
    this.id = '',
    required this.type,
    this.guestLabel = '',
    this.createdAt = '',
  });

  /// Present on `/floor` (and on the session summary) so the panel can clear
  /// exactly one ask. Older payloads omit it; an empty id means "display only".
  final String id;
  final String type;
  final String guestLabel;
  final String createdAt;

  factory PanelServiceRequestSummary.fromJson(Map<String, dynamic> json) =>
      PanelServiceRequestSummary(
        id: _text(json['_id'] ?? json['id']),
        type: _text(json['type']),
        guestLabel: _text(json['guestLabel']),
        createdAt: _text(json['createdAt']),
      );
}

/// The live party at a physical table. The backend summarizes the open
/// [TableSession] without exposing guest bearer hashes; the panel only needs
/// the code, party size, bill and pending requests to run the floor.
class PanelSessionSummary {
  const PanelSessionSummary({
    required this.id,
    required this.code,
    this.status = 'open',
    this.guests = 0,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.paid = 0,
    this.pendingRequests = 0,
    this.requests = const [],
    this.openedAt = '',
    this.closedAt = '',
  });

  final String id;
  final String code;
  final String status;
  final int guests;
  final double subtotal;
  final double tax;
  final double total;
  final double paid;
  final int pendingRequests;
  final List<PanelServiceRequestSummary> requests;
  final String openedAt;
  final String closedAt;

  double get remaining {
    final value = total - paid;
    return value > 0 ? value : 0;
  }

  bool get hasPendingRequests => pendingRequests > 0 || requests.isNotEmpty;

  factory PanelSessionSummary.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'];
    final requests = rawRequests is List
        ? rawRequests
              .whereType<Map>()
              .map(
                (entry) => PanelServiceRequestSummary.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList()
        : const <PanelServiceRequestSummary>[];
    final rawGuests = json['guests'];
    final guests = rawGuests is List ? rawGuests.length : _int(rawGuests);
    final rawPending = json['pendingRequests'];
    final pendingRequests = rawPending == null
        ? requests.length
        : _int(rawPending);

    return PanelSessionSummary(
      id: _text(json['_id'] ?? json['id']),
      code: _text(json['code']),
      status: _text(json['status']).isEmpty ? 'open' : _text(json['status']),
      guests: guests,
      subtotal: _doubleOrNull(json['subtotal']) ?? 0,
      tax: _doubleOrNull(json['tax']) ?? 0,
      total: _doubleOrNull(json['total']) ?? 0,
      paid: _doubleOrNull(json['paid']) ?? 0,
      pendingRequests: pendingRequests,
      requests: requests,
      openedAt: _text(json['openedAt']),
      closedAt: _text(json['closedAt']),
    );
  }
}

/// One line on a live order: what was ordered, how it was modified, and what
/// the guest wrote next to it.
class PanelOrderLine {
  const PanelOrderLine({
    required this.name,
    this.nameAr = '',
    this.nameEn = '',
    this.quantity = 0,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.note = '',
    this.specifications = const [],
  });

  final String name;
  final String nameAr;
  final String nameEn;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String note;

  /// Add-on labels with their price delta, already flattened for display.
  final List<String> specifications;

  /// The Arabic name when the app is in Arabic and one exists, else whatever
  /// the server snapshotted.
  String displayName(bool arabic) => arabic && nameAr.isNotEmpty
      ? nameAr
      : (nameEn.isNotEmpty ? nameEn : name);

  factory PanelOrderLine.fromJson(Map<String, dynamic> json) {
    final rawSpecs = json['specifications'];
    final specs = rawSpecs is List
        ? rawSpecs
              .whereType<Map>()
              .map((spec) {
                final name = _text(spec['name'] ?? spec['key']);
                final price = _doubleOrNull(spec['price']) ?? 0;
                return price > 0
                    ? '$name (+${price.toStringAsFixed(2)})'
                    : name;
              })
              .where((label) => label.isNotEmpty)
              .toList()
        : const <String>[];
    return PanelOrderLine(
      name: _text(json['name']),
      nameAr: _text(json['nameAr']),
      nameEn: _text(json['nameEn']),
      quantity: _int(json['quantity']),
      unitPrice: _doubleOrNull(json['unitPrice']) ?? 0,
      lineTotal: _doubleOrNull(json['lineTotal']) ?? 0,
      note: _text(json['note']),
      specifications: specs,
    );
  }
}

/// A live kitchen ticket attached to a table.
class PanelTableOrder {
  const PanelTableOrder({
    required this.id,
    this.orderNumber = '',
    this.status = 'draft',
    this.totalPrice = 0,
    this.subtotal = 0,
    this.tax = 0,
    this.itemCount = 0,
    this.createdAt,
    this.note = '',
    this.items = const [],
  });

  final String id;
  final String orderNumber;
  final String status;
  final double totalPrice;
  final double subtotal;
  final double tax;
  final int itemCount;
  final DateTime? createdAt;
  final String note;
  final List<PanelOrderLine> items;

  bool get isOpen => status != 'served' && status != 'cancelled';

  factory PanelTableOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['menuItems'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    PanelOrderLine.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <PanelOrderLine>[];
    return PanelTableOrder(
      id: _text(json['_id'] ?? json['id']),
      orderNumber: _text(json['orderNumber']),
      status: _text(json['status'] ?? json['orderStatus']).isEmpty
          ? 'draft'
          : _text(json['status'] ?? json['orderStatus']),
      totalPrice: _doubleOrNull(json['totalPrice']) ?? 0,
      subtotal: _doubleOrNull(json['subtotal']) ?? 0,
      tax: _doubleOrNull(json['tax']) ?? 0,
      itemCount: json['itemCount'] != null
          ? _int(json['itemCount'])
          : items.fold(0, (sum, line) => sum + line.quantity),
      createdAt: DateTime.tryParse(_text(json['createdAt'])),
      note: _text(json['note']),
      items: items,
    );
  }
}

/// The booking a table is holding right now (seated or next arrival today).
class PanelTableReservation {
  const PanelTableReservation({
    required this.id,
    this.startAt,
    this.endAt,
    this.guestsCount = 0,
    this.status = 'pending',
    this.customerName = '',
    this.customerPhone = '',
    this.checkInCode = '',
    this.tableIds = const [],
  });

  final String id;
  final DateTime? startAt;
  final DateTime? endAt;
  final int guestsCount;
  final String status;
  final String customerName;
  final String customerPhone;
  final String checkInCode;
  final List<String> tableIds;

  bool get isSeated => status == 'seated';
  bool get isExpected => status == 'pending' || status == 'confirmed';

  factory PanelTableReservation.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tableIds'] ?? json['physicalTableIds'];
    return PanelTableReservation(
      id: _text(json['_id'] ?? json['id']),
      startAt: DateTime.tryParse(_text(json['startAt'])),
      endAt: DateTime.tryParse(_text(json['endAt'])),
      guestsCount: _int(json['guestsCount']),
      status: _text(json['status']).isEmpty ? 'pending' : _text(json['status']),
      customerName: _text(json['customerName'] ?? json['name']),
      customerPhone: _text(json['customerPhone'] ?? json['phone']),
      checkInCode: _text(json['checkInCode']),
      tableIds: rawTables is List ? rawTables.map(_text).toList() : const [],
    );
  }
}

class PanelPhysicalTable {
  const PanelPhysicalTable({
    required this.id,
    required this.tableTypeId,
    required this.code,
    required this.seats,
    required this.status,
    this.zone, // T28: free-form zone label (null = unassigned)
    this.occupied, // T28: server-side occupancy (null = field absent)
    this.openSession, // QR web ordering: the live party, when one exists
    this.typeLabel = '',
    this.displayStatus = '',
    this.orders = const [],
    this.reservation,
    this.requests = const [],
    this.x,
    this.y,
  });

  final String id;
  final String tableTypeId;
  final String code;
  final int seats;
  final String status;
  final String? zone;

  /// Human label of the table type, joined by `/floor` so a row can say
  /// "Terrace · 4 seats" without a second lookup.
  final String typeLabel;

  /// The single status the control room draws:
  /// `occupied → inactive → reserved → available`, computed by the server.
  /// Empty on older payloads; [floorStatus] then falls back to local facts.
  final String displayStatus;

  /// Live kitchen tickets for this table, oldest first.
  final List<PanelTableOrder> orders;

  /// Today's booking this table is holding, when one exists.
  final PanelTableReservation? reservation;

  /// Pending guest asks with ids, so the sheet can clear exactly one.
  final List<PanelServiceRequestSummary> requests;

  /// Server-computed occupancy (E2 rule: the table has an order whose
  /// `orderStatus` is neither `served` nor `cancelled`).
  ///
  /// `null` means the backend did not send the field at all. The client
  /// never re-derives occupancy from a second rule — this screen has no
  /// order list to derive it from — so an absent field simply reads as
  /// "not occupied" instead of inventing a third rule.
  final bool? occupied;

  /// The live browser party at this table, or `null` when nobody is seated.
  final PanelSessionSummary? openSession;

  final double? x; // null → tray (Task 4: unpositioned)
  final double? y;

  bool get positioned => x != null && y != null;

  bool get hasOpenSession => openSession != null;

  /// The authoritative occupancy flag used for colours and the delete gate.
  /// A live session counts even before its first order is sent.
  bool get isOccupied => (occupied ?? false) || hasOpenSession;

  /// What the card draws. `/floor` sends the server's answer; when an older
  /// endpoint omits it, the same precedence is applied to the facts that are
  /// present (`occupied → inactive → reserved → available`).
  String get floorStatus {
    if (displayStatus.isNotEmpty) return displayStatus;
    if (isOccupied) return 'occupied';
    if (status == 'inactive') return 'inactive';
    if (status == 'reserved' || reservation != null) return 'reserved';
    return 'available';
  }

  bool get isOccupiedNow => floorStatus == 'occupied';

  /// Guest asks that still need a human. `/floor` sends these with ids; the
  /// old per-type payload only had them nested on the session.
  List<PanelServiceRequestSummary> get pendingRequests =>
      requests.isNotEmpty ? requests : (openSession?.requests ?? const []);

  bool get hasAttention => pendingRequests.isNotEmpty;

  int get openItemCount =>
      orders.fold(0, (sum, order) => sum + order.itemCount);

  /// The bill to collect. The party snapshot is authoritative (it survives a
  /// menu reprice); the live tickets are the fallback before the first close.
  double get billTotal {
    final session = openSession;
    if (session != null && session.total > 0) return session.total;
    return orders.fold(0.0, (sum, order) => sum + order.totalPrice);
  }

  double get billPaid => openSession?.paid ?? 0;

  double get billRemaining {
    final value = billTotal - billPaid;
    return value > 0 ? value : 0;
  }

  int get guestCount => openSession?.guests ?? reservation?.guestsCount ?? 0;

  DateTime? get seatedSince =>
      DateTime.tryParse(openSession?.openedAt ?? '')?.toLocal();

  PanelPhysicalTable copyWith({
    String? code,
    int? seats,
    String? status,
    String? zone,
    bool clearZone = false,
    bool? occupied,
    PanelSessionSummary? openSession,
    bool clearOpenSession = false,
    String? typeLabel,
    String? displayStatus,
    List<PanelTableOrder>? orders,
    PanelTableReservation? reservation,
    bool clearReservation = false,
    List<PanelServiceRequestSummary>? requests,
    double? x,
    double? y,
  }) => PanelPhysicalTable(
    id: id,
    tableTypeId: tableTypeId,
    code: code ?? this.code,
    seats: seats ?? this.seats,
    status: status ?? this.status,
    zone: clearZone ? null : (zone ?? this.zone),
    occupied: occupied ?? this.occupied,
    openSession: clearOpenSession ? null : (openSession ?? this.openSession),
    typeLabel: typeLabel ?? this.typeLabel,
    displayStatus: displayStatus ?? this.displayStatus,
    orders: orders ?? this.orders,
    reservation: clearReservation ? null : (reservation ?? this.reservation),
    requests: requests ?? this.requests,
    x: x ?? this.x,
    y: y ?? this.y,
  );

  factory PanelPhysicalTable.fromJson(Map<String, dynamic> json) {
    final pos = json['position'];
    final typeId = json['tableTypeId'];
    final rawOccupied = json['occupied'];
    final rawSession = json['session'] ?? json['openSession'];
    final rawOrders = json['orders'];
    final rawReservation = json['reservation'];
    final rawRequests = json['pendingRequests'] ?? json['requests'];
    final rawTypeLabel = json['typeLabel'];

    final orders = rawOrders is List
        ? rawOrders
              .whereType<Map>()
              .map(
                (order) =>
                    PanelTableOrder.fromJson(Map<String, dynamic>.from(order)),
              )
              .toList()
        : const <PanelTableOrder>[];
    final requests = rawRequests is List
        ? rawRequests
              .whereType<Map>()
              .map(
                (request) => PanelServiceRequestSummary.fromJson(
                  Map<String, dynamic>.from(request),
                ),
              )
              .toList()
        : const <PanelServiceRequestSummary>[];

    return PanelPhysicalTable(
      id: _text(json['_id'] ?? json['id']),
      tableTypeId: typeId is Map ? _text(typeId['_id']) : _text(typeId),
      code: _text(json['code']),
      seats: _int(json['seats']),
      status: _text(json['status']).isEmpty
          ? 'available'
          : _text(json['status']),
      zone: _localized(json['zone']).isEmpty ? null : _localized(json['zone']),
      occupied: rawOccupied is bool ? rawOccupied : null,
      openSession: rawSession is Map
          ? PanelSessionSummary.fromJson(Map<String, dynamic>.from(rawSession))
          : null,
      typeLabel: _text(rawTypeLabel).isEmpty && typeId is Map
          ? _localized(typeId['label'])
          : _text(rawTypeLabel),
      displayStatus: _text(json['displayStatus']),
      orders: orders,
      reservation: rawReservation is Map
          ? PanelTableReservation.fromJson(
              Map<String, dynamic>.from(rawReservation),
            )
          : null,
      requests: requests,
      x: pos is Map ? _doubleOrNull(pos['x']) : null,
      y: pos is Map ? _doubleOrNull(pos['y']) : null,
    );
  }
}
