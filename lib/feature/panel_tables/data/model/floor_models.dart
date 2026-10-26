// lib/feature/panel_tables/data/model/floor_models.dart
//
// The control-room payload. `GET /restaurant-owner/floor` answers the whole
// floor in one call: money, occupancy, tables (with their live party, tickets,
// reservation and pending asks) plus today's bookings. Before this the screen
// issued one request per table type and had no orders or reservations at all.
import 'table_models.dart';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _text(Object? value) => value?.toString() ?? '';

/// Which slice of the floor the list/canvas shows. Lives with the data model
/// so presentational widgets can filter without depending on the cubit.
enum FloorFilter { all, occupied, available, reserved, attention }

/// The today strip. Every number is a server count or sum — none is derived
/// from another by the client, except the two percentages the server also
/// computes (kept here only as a fallback for older payloads).
class PanelFloorKpi {
  const PanelFloorKpi({
    this.salesToday = 0,
    this.ordersToday = 0,
    this.avgTicket = 0,
    this.openBills = 0,
    this.openBillsTotal = 0,
    this.occupiedTables = 0,
    this.totalTables = 0,
    this.occupancyPct = 0,
    this.reservationsToday = 0,
    this.seatedNow = 0,
    this.waitlistCount = 0,
    this.nextReservationAt,
  });

  final double salesToday;
  final int ordersToday;
  final double avgTicket;
  final int openBills;
  final double openBillsTotal;
  final int occupiedTables;
  final int totalTables;
  final int occupancyPct;
  final int reservationsToday;
  final int seatedNow;
  final int waitlistCount;
  final DateTime? nextReservationAt;

  bool get hasSales => salesToday > 0;

  factory PanelFloorKpi.fromJson(Map<String, dynamic> json) => PanelFloorKpi(
    salesToday: _num(json['salesToday']),
    ordersToday: _int(json['ordersToday']),
    avgTicket: _num(json['avgTicket']),
    openBills: _int(json['openBills']),
    openBillsTotal: _num(json['openBillsTotal']),
    occupiedTables: _int(json['occupiedTables']),
    totalTables: _int(json['totalTables']),
    occupancyPct: _int(json['occupancyPct']),
    reservationsToday: _int(json['reservationsToday']),
    seatedNow: _int(json['seatedNow']),
    waitlistCount: _int(json['waitlistCount']),
    nextReservationAt: DateTime.tryParse(
      _text(json['nextReservationAt']),
    )?.toLocal(),
  );
}

/// One printed/live table code. `version` increments on rotation, which is
/// the only operation that kills cards already on the tables.
class PanelTableQr {
  const PanelTableQr({
    required this.tableId,
    required this.code,
    required this.url,
    this.version = 0,
    this.rotatedAt,
  });

  final String tableId;
  final String code;
  final String url;
  final int version;
  final DateTime? rotatedAt;

  /// The short path shown under the QR (the full URL is long).
  String get shortPath {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty) return url;
    return '${uri.host}${uri.path}';
  }

  factory PanelTableQr.fromJson(Map<String, dynamic> json) => PanelTableQr(
    tableId: _text(json['tableId']),
    code: _text(json['code']),
    url: _text(json['url']),
    version: _int(json['version']),
    rotatedAt: DateTime.tryParse(_text(json['rotatedAt']))?.toLocal(),
  );
}

/// The whole floor in one immutable snapshot.
class PanelFloorSnapshot {
  const PanelFloorSnapshot({
    required this.kpi,
    required this.tables,
    this.types = const [],
    this.reservations = const [],
    this.generatedAt,
  });

  final PanelFloorKpi kpi;
  final List<PanelPhysicalTable> tables;
  final List<PanelTableType> types;
  final List<PanelTableReservation> reservations;
  final DateTime? generatedAt;

  bool get isEmpty => tables.isEmpty;

  /// A table with no saved position would render in the tray; the screen
  /// auto-grids those instead of showing an empty canvas.
  List<PanelPhysicalTable> get unpositioned =>
      tables.where((table) => !table.positioned).toList();

  bool get hasLayout => tables.any((table) => table.positioned);

  factory PanelFloorSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'];
    final rawTypes = json['types'];
    final rawReservations = json['reservations'];
    return PanelFloorSnapshot(
      kpi: json['kpi'] is Map
          ? PanelFloorKpi.fromJson(
              Map<String, dynamic>.from(json['kpi'] as Map),
            )
          : const PanelFloorKpi(),
      tables: rawTables is List
          ? rawTables
                .whereType<Map>()
                .map(
                  (row) => PanelPhysicalTable.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
      types: rawTypes is List
          ? rawTypes
                .whereType<Map>()
                .map(
                  (row) =>
                      PanelTableType.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList()
          : const [],
      reservations: rawReservations is List
          ? rawReservations
                .whereType<Map>()
                .map(
                  (row) => PanelTableReservation.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
      generatedAt: DateTime.tryParse(_text(json['generatedAt']))?.toLocal(),
    );
  }
}
