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

int _int(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}') ?? 0;

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

  factory PanelTableType.fromJson(Map<String, dynamic> json) =>
      PanelTableType(
        id: _text(json['_id'] ?? json['id']),
        label: _localized(json['label']),
        seatsPerTable: _int(json['seatsPerTable']),
        tablesCount: _int(json['tablesCount']),
      );
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
    this.x,
    this.y,
  });

  final String id;
  final String tableTypeId;
  final String code;
  final int seats;
  final String status;
  final String? zone;

  /// Server-computed occupancy (E2 rule: the table has an order whose
  /// `orderStatus` is neither `served` nor `cancelled`).
  ///
  /// `null` means the backend did not send the field at all. The client
  /// never re-derives occupancy from a second rule — this screen has no
  /// order list to derive it from — so an absent field simply reads as
  /// "not occupied" instead of inventing a third rule.
  final bool? occupied;

  final double? x; // null → tray (Task 4: unpositioned)
  final double? y;

  bool get positioned => x != null && y != null;

  /// The authoritative occupancy flag used for colours and the delete gate.
  bool get isOccupied => occupied ?? false;

  PanelPhysicalTable copyWith({
    String? code,
    int? seats,
    String? status,
    String? zone,
    bool clearZone = false,
    bool? occupied,
    double? x,
    double? y,
  }) =>
      PanelPhysicalTable(
        id: id,
        tableTypeId: tableTypeId,
        code: code ?? this.code,
        seats: seats ?? this.seats,
        status: status ?? this.status,
        zone: clearZone ? null : (zone ?? this.zone),
        occupied: occupied ?? this.occupied,
        x: x ?? this.x,
        y: y ?? this.y,
      );

  factory PanelPhysicalTable.fromJson(Map<String, dynamic> json) {
    final pos = json['position'];
    final typeId = json['tableTypeId'];
    final rawOccupied = json['occupied'];
    return PanelPhysicalTable(
      id: _text(json['_id'] ?? json['id']),
      tableTypeId: typeId is Map ? _text(typeId['_id']) : _text(typeId),
      code: _text(json['code']),
      seats: _int(json['seats']),
      status: _text(json['status']).isEmpty ? 'available' : _text(json['status']),
      zone: _localized(json['zone']).isEmpty ? null : _localized(json['zone']),
      occupied: rawOccupied is bool ? rawOccupied : null,
      x: pos is Map ? _doubleOrNull(pos['x']) : null,
      y: pos is Map ? _doubleOrNull(pos['y']) : null,
    );
  }
}
