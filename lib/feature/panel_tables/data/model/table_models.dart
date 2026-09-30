// lib/feature/panel_tables/data/model/table_models.dart
class PanelTableType {
  const PanelTableType(
      {required this.id,
      required this.label,
      this.seatsPerTable = 0,
      this.tablesCount = 0});

  final String id;
  final String label;
  final int seatsPerTable;
  final int tablesCount;

  factory PanelTableType.fromJson(Map<String, dynamic> json) =>
      PanelTableType(
        id: json['_id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        seatsPerTable: (json['seatsPerTable'] as num?)?.toInt() ?? 0,
        tablesCount: (json['tablesCount'] as num?)?.toInt() ?? 0,
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
    this.occupied = false, // T28: computed server-side (E2 open-order rule)
    this.x,
    this.y,
  });

  final String id;
  final String tableTypeId;
  final String code;
  final int seats;
  final String status;
  final String? zone;
  final bool occupied;
  final double? x; // null → tray (Task 4: unpositioned)
  final double? y;

  bool get positioned => x != null && y != null;

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
    return PanelPhysicalTable(
      id: json['_id'] as String? ?? '',
      tableTypeId: typeId is Map ? typeId['_id'] as String? ?? '' : '$typeId',
      code: json['code'] as String? ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'available',
      zone: json['zone'] as String?,
      occupied: json['occupied'] as bool? ?? false,
      x: pos is Map ? (pos['x'] as num?)?.toDouble() : null,
      y: pos is Map ? (pos['y'] as num?)?.toDouble() : null,
    );
  }
}
