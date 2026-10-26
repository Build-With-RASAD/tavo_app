// lib/feature/panel_tables/ui/logic/tables_panel_state.dart
part of 'tables_panel_cubit.dart';

sealed class TablesPanelState {
  const TablesPanelState();
}

class TablesPanelInitial extends TablesPanelState {
  const TablesPanelInitial();
}

class TablesPanelLoading extends TablesPanelState {
  const TablesPanelLoading();
}

class TablesPanelLoaded extends TablesPanelState {
  const TablesPanelLoaded({
    required this.types,
    required this.tables,
    required this.kpi,
    this.reservations = const [],
    this.generatedAt,
    this.selectedTypeId,
    this.query = '',
    this.zone,
    this.filter = FloorFilter.all,
    this.saving = false,
    this.creating = false,
    this.actionId,
    this.actionError,
    this.stale = false,
    this.arranging = false,
    this.selecting = false,
    this.selected = const {},
    this.qr = const {},
    this.qrLoadingId,
    this.qrError,
  });

  final List<PanelTableType> types;
  final List<PanelPhysicalTable> tables;
  final PanelFloorKpi kpi;
  final List<PanelTableReservation> reservations;
  final DateTime? generatedAt;

  /// Only used to pre-select the type in the create-table form. The floor
  /// itself is never scoped by type — one payload covers every table.
  final String? selectedTypeId;

  final String query;
  final String? zone;
  final FloorFilter filter;

  final bool saving;
  final bool creating;
  final String? actionId;
  final String? actionError;

  /// A background poll failed; the rows on screen are the last good snapshot.
  final bool stale;

  final bool arranging;
  final bool selecting;
  final Set<String> selected;

  /// QR codes fetched in this session, keyed by table id.
  final Map<String, PanelTableQr> qr;
  final String? qrLoadingId;
  final String? qrError;

  bool get isEmpty => tables.isEmpty;

  /// Zones with their table counts, busiest last (alphabetical tie-break).
  List<({String zone, int count})> get zones {
    final counts = <String, int>{};
    for (final table in tables) {
      final zone = table.zone;
      if (zone == null || zone.isEmpty) continue;
      counts[zone] = (counts[zone] ?? 0) + 1;
    }
    final rows =
        [
          for (final entry in counts.entries)
            (zone: entry.key, count: entry.value),
        ]..sort((a, b) {
          final byCount = a.count.compareTo(b.count);
          return byCount != 0 ? byCount : a.zone.compareTo(b.zone);
        });
    return rows;
  }

  /// Tables after search + zone + status filter. Search matches the table
  /// code, its zone, the party code, or the reserved guest's name/phone.
  List<PanelPhysicalTable> get visibleTables {
    final needle = query.trim().toLowerCase();
    return tables.where((table) {
      if (zone != null && table.zone != zone) return false;
      switch (filter) {
        case FloorFilter.occupied:
          if (!table.isOccupiedNow) return false;
        case FloorFilter.available:
          if (table.floorStatus != 'available') return false;
        case FloorFilter.reserved:
          if (table.floorStatus != 'reserved') return false;
        case FloorFilter.attention:
          if (!table.hasAttention) return false;
        case FloorFilter.all:
          break;
      }
      if (needle.isEmpty) return true;
      final reservation = table.reservation;
      final haystack = [
        table.code,
        table.zone ?? '',
        table.typeLabel,
        table.openSession?.code ?? '',
        reservation?.customerName ?? '',
        reservation?.customerPhone ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  /// Every table that needs a human, oldest ask first — the attention rail.
  List<PanelPhysicalTable> get attentionTables {
    final rows = tables.where((table) => table.hasAttention).toList();
    rows.sort((a, b) {
      final aAt = a.pendingRequests.isEmpty
          ? null
          : DateTime.tryParse(a.pendingRequests.first.createdAt);
      final bAt = b.pendingRequests.isEmpty
          ? null
          : DateTime.tryParse(b.pendingRequests.first.createdAt);
      if (aAt == null || bAt == null) return a.code.compareTo(b.code);
      return aAt.compareTo(bAt);
    });
    return rows;
  }

  /// Today's bookings still worth showing: expected or seated, earliest first.
  List<PanelTableReservation> get upcomingReservations {
    final rows = reservations.where((r) => r.isExpected || r.isSeated).toList()
      ..sort((a, b) {
        final aAt = a.startAt;
        final bAt = b.startAt;
        if (aAt == null || bAt == null) return 0;
        return aAt.compareTo(bAt);
      });
    return rows;
  }

  /// A reservation may hold several tables; this is the label the rail shows.
  String tableLabelFor(PanelTableReservation reservation) {
    if (reservation.tableIds.isEmpty) return '';
    final codes = <String>[];
    for (final id in reservation.tableIds) {
      for (final table in tables) {
        if (table.id == id) codes.add(table.code);
      }
    }
    return codes.join(' · ');
  }

  PanelPhysicalTable? tableById(String id) {
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  TablesPanelLoaded copyWith({
    List<PanelTableType>? types,
    List<PanelPhysicalTable>? tables,
    PanelFloorKpi? kpi,
    List<PanelTableReservation>? reservations,
    DateTime? generatedAt,
    String? selectedTypeId,
    String? query,
    String? zone,
    bool clearZone = false,
    FloorFilter? filter,
    bool? saving,
    bool? creating,
    String? actionId,
    String? actionError,
    bool? stale,
    bool? arranging,
    bool? selecting,
    Set<String>? selected,
    Map<String, PanelTableQr>? qr,
    String? qrLoadingId,
    String? qrError,
    bool clearAction = false,
    bool clearError = false,
    bool clearQrLoading = false,
    bool clearQrError = false,
  }) => TablesPanelLoaded(
    types: types ?? this.types,
    tables: tables ?? this.tables,
    kpi: kpi ?? this.kpi,
    reservations: reservations ?? this.reservations,
    generatedAt: generatedAt ?? this.generatedAt,
    selectedTypeId: selectedTypeId ?? this.selectedTypeId,
    query: query ?? this.query,
    zone: clearZone ? null : (zone ?? this.zone),
    filter: filter ?? this.filter,
    saving: saving ?? this.saving,
    creating: creating ?? this.creating,
    actionId: clearAction ? null : (actionId ?? this.actionId),
    actionError: clearError ? null : (actionError ?? this.actionError),
    stale: stale ?? this.stale,
    arranging: arranging ?? this.arranging,
    selecting: selecting ?? this.selecting,
    selected: selected ?? this.selected,
    qr: qr ?? this.qr,
    qrLoadingId: clearQrLoading ? null : (qrLoadingId ?? this.qrLoadingId),
    qrError: clearQrError ? null : (qrError ?? this.qrError),
  );
}

class TablesPanelError extends TablesPanelState {
  const TablesPanelError(this.message);
  final String message;
}
