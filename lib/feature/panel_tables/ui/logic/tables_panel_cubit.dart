// lib/feature/panel_tables/ui/logic/tables_panel_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/floor_models.dart';
import '../../data/model/table_models.dart';
import '../../data/repo/tables_panel_repo.dart';

part 'tables_panel_state.dart';

/// The restaurant floor control room.
///
/// One aggregate read (`GET /floor`) drives everything: the today strip, the
/// attention rail, the reservations rail, the floor canvas and the list. A
/// 25 s silent poll keeps it live without flashing skeletons; a failed poll
/// keeps the last good rows and raises [TablesPanelLoaded.stale] instead of
/// replacing a working floor with an error page.
///
/// Mutations patch optimistically and then re-read the floor, so the card can
/// never disagree with the server about who is sitting where.
class TablesPanelCubit extends Cubit<TablesPanelState> {
  TablesPanelCubit(
    this._repo, {
    required this.restaurantId,
    this.pollInterval = const Duration(seconds: 25),
    this.autoRefresh = true,
  }) : super(const TablesPanelInitial());

  final TablesPanelRepo _repo;
  final String restaurantId;
  final Duration pollInterval;

  /// Tests turn this off so a widget test never leaves a pending timer.
  final bool autoRefresh;

  Timer? _timer;
  bool _inFlight = false;

  /// Loads the floor once, then keeps polling while the screen is alive.
  Future<void> load() async {
    if (isClosed || _inFlight) return;
    final current = state;
    if (current is! TablesPanelLoaded) emit(const TablesPanelLoading());
    await _fetch(silent: current is TablesPanelLoaded);
    _startPolling();
  }

  void _startPolling() {
    if (!autoRefresh || _timer != null) return;
    _timer = Timer.periodic(pollInterval, (_) => refresh(silent: true));
  }

  /// Pull-to-refresh / retry. Silent refreshes keep the current filters and
  /// never blank the screen.
  Future<void> refresh({bool silent = false}) async {
    if (isClosed) return;
    await _fetch(silent: silent);
  }

  Future<void> _fetch({required bool silent}) async {
    if (_inFlight) return;
    _inFlight = true;
    final before = state;
    try {
      final snapshot = await _repo.getFloor(restaurantId);
      if (isClosed) return;
      final base = before is TablesPanelLoaded ? before : null;
      emit(
        TablesPanelLoaded(
          types: snapshot.types,
          tables: snapshot.tables,
          kpi: snapshot.kpi,
          reservations: snapshot.reservations,
          generatedAt: snapshot.generatedAt,
          selectedTypeId:
              base?.selectedTypeId ??
              (snapshot.types.isNotEmpty ? snapshot.types.first.id : null),
          query: base?.query ?? '',
          zone: base?.zone,
          filter: base?.filter ?? FloorFilter.all,
          stale: false,
          arranging: base?.arranging ?? false,
          selecting: base?.selecting ?? false,
          selected: base?.selected ?? const {},
          qr: base?.qr ?? const {},
          qrLoadingId: base?.qrLoadingId,
          qrError: base?.qrError,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final base = state is TablesPanelLoaded
          ? state as TablesPanelLoaded
          : before is TablesPanelLoaded
          ? before
          : null;
      if (base != null) {
        emit(base.copyWith(stale: true));
      } else {
        emit(TablesPanelError(_message(e)));
      }
    } finally {
      _inFlight = false;
    }
  }

  // ── Filters ────────────────────────────────────────────────────────────

  void setQuery(String value) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(query: value));
  }

  void setZone(String? zone) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(zone == null ? s.copyWith(clearZone: true) : s.copyWith(zone: zone));
  }

  void setFilter(FloorFilter filter) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(filter: filter));
  }

  void clearFilters() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(query: '', clearZone: true, filter: FloorFilter.all));
  }

  // ── Arrange mode ───────────────────────────────────────────────────────

  void enterArrange() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(arranging: true));
  }

  void exitArrange() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(arranging: false));
  }

  /// Edit-mode snap-to-grid: rounds a fraction to the nearest 0.05 step
  /// (spec decision 1 — exact, two-decimal values, no float dust).
  static double snapToGrid(double v) =>
      double.parse(((v / 0.05).round() * 0.05).toStringAsFixed(2));

  /// Local-only move, clamped to the `[0,1]` editor box. Persisted on save.
  void moveTable(String id, double x, double y, {bool snap = false}) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    final fx = snap ? snapToGrid(x) : x;
    final fy = snap ? snapToGrid(y) : y;
    emit(
      s.copyWith(
        tables: [
          for (final t in s.tables)
            if (t.id == id)
              t.copyWith(x: fx.clamp(0.0, 1.0), y: fy.clamp(0.0, 1.0))
            else
              t,
        ],
      ),
    );
  }

  /// Persists every table's fractional position to `PUT /floor-plan`.
  Future<bool> saveFloorPlan() async {
    final s = state;
    if (s is! TablesPanelLoaded || s.saving) return false;
    emit(s.copyWith(saving: true, clearError: true));
    try {
      await _repo.saveFloorPlan(restaurantId, [
        for (final t in s.tables) (id: t.id, x: t.x, y: t.y),
      ]);
      if (isClosed) return false;
      emit((state as TablesPanelLoaded).copyWith(saving: false));
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          saving: false,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  // ── Selection (bulk) ───────────────────────────────────────────────────

  void setSelecting(bool value) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(selecting: value, selected: value ? s.selected : const {}));
  }

  void toggleSelected(String id) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    final next = {...s.selected};
    if (!next.add(id)) next.remove(id);
    emit(s.copyWith(selected: next, selecting: true));
  }

  void selectAllVisible() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(
      s.copyWith(
        selecting: true,
        selected: s.visibleTables.map((t) => t.id).toSet(),
      ),
    );
  }

  void clearSelection() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(selected: const {}, selecting: false));
  }

  // ── Mutations ──────────────────────────────────────────────────────────

  /// Cycles available ↔ inactive. Callers gate this on occupancy: hiding a
  /// table with guests at it is never what staff meant. (The old screen sent
  /// `unavailable`, which the backend enum rejects — every tap 400'd.)
  Future<bool> toggleStatus(PanelPhysicalTable table) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    final next = table.status == 'inactive' ? 'available' : 'inactive';
    return setStatus(table.id, next);
  }

  Future<bool> setStatus(String id, String status) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated = await _repo.updatePhysicalTableStatus(
        restaurantId: restaurantId,
        id: id,
        status: status,
      );
      if (isClosed) return false;
      _patch(updated);
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  Future<bool> createTable({
    required String tableTypeId,
    required String code,
    required int seats,
    String? zone,
  }) async {
    final s = state;
    if (s is! TablesPanelLoaded || s.creating) return false;
    emit(s.copyWith(creating: true, clearError: true));
    try {
      await _repo.createPhysicalTable(
        restaurantId: restaurantId,
        tableTypeId: tableTypeId,
        code: code,
        seats: seats,
        zone: zone,
      );
      if (isClosed) return false;
      emit((state as TablesPanelLoaded).copyWith(creating: false));
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          creating: false,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  Future<bool> updateTable(
    String id, {
    required String code,
    required int seats,
    String? zone,
    bool clearZone = false,
  }) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated = await _repo.updatePhysicalTable(
        restaurantId: restaurantId,
        id: id,
        code: code,
        seats: seats,
        zone: zone,
        clearZone: clearZone,
      );
      if (isClosed) return false;
      _patch(updated);
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  Future<bool> deleteTable(String id) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      await _repo.deletePhysicalTable(restaurantId: restaurantId, id: id);
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          tables: [
            for (final t in s.tables)
              if (t.id != id) t,
          ],
          selected: {...s.selected}..remove(id),
        ),
      );
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  /// POST /physical-tables/:id/settle — the counter recorded cash/card.
  /// The backend closes the party and frees the table; re-read to prove it.
  Future<bool> settleTable(String id, {double? amount}) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      await _repo.settleTable(
        restaurantId: restaurantId,
        id: id,
        amount: amount,
      );
      if (isClosed) return false;
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  /// Clears one guest ask. The badge disappears from every surface because
  /// the floor is re-read rather than patched locally.
  Future<bool> handleRequest(String tableId, String requestId) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: tableId, clearError: true));
    try {
      await _repo.handleServiceRequest(
        restaurantId: restaurantId,
        tableId: tableId,
        requestId: requestId,
      );
      if (isClosed) return false;
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  /// Door actions on today's arrivals. Both re-read the floor: seating a
  /// party changes two tables' worth of state in the real system.
  Future<bool> seatReservation(String reservationId) =>
      _reservationAction(reservationId, 'seat');

  Future<bool> markReservationNoShow(String reservationId) =>
      _reservationAction(reservationId, 'no-show');

  Future<bool> _reservationAction(String id, String action) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      await _repo.reservationAction(
        restaurantId: restaurantId,
        id: id,
        action: action,
      );
      if (isClosed) return false;
      await refresh(silent: true);
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
      return false;
    }
  }

  Future<void> bulkSetZone(List<String> ids, String zone) async {
    if (ids.isEmpty) return;
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(actionId: ids.first, clearError: true));
    try {
      for (final id in ids) {
        final updated = await _repo.updatePhysicalTable(
          restaurantId: restaurantId,
          id: id,
          zone: zone,
        );
        if (isClosed) return;
        _patch(updated);
      }
      await refresh(silent: true);
    } catch (e) {
      if (isClosed) return;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
    }
  }

  Future<void> bulkSetStatus(List<String> ids, String status) async {
    if (ids.isEmpty) return;
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(actionId: ids.first, clearError: true));
    try {
      for (final id in ids) {
        final updated = await _repo.updatePhysicalTableStatus(
          restaurantId: restaurantId,
          id: id,
          status: status,
        );
        if (isClosed) return;
        _patch(updated);
      }
      await refresh(silent: true);
    } catch (e) {
      if (isClosed) return;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearAction: true,
          actionError: _message(e),
        ),
      );
    }
  }

  // ── QR ─────────────────────────────────────────────────────────────────

  /// Idempotent: reprinting a card must never invalidate the printed one.
  Future<PanelTableQr?> loadQr(String tableId) async {
    final s = state;
    if (s is! TablesPanelLoaded) return null;
    final cached = s.qr[tableId];
    if (cached != null) return cached;
    if (s.qrLoadingId == tableId) return null;
    emit(s.copyWith(qrLoadingId: tableId, clearQrError: true));
    try {
      final qr = await _repo.getTableQr(
        restaurantId: restaurantId,
        tableId: tableId,
      );
      if (isClosed) return null;
      final now = state as TablesPanelLoaded;
      emit(now.copyWith(qr: {...now.qr, tableId: qr}, clearQrLoading: true));
      return qr;
    } catch (e) {
      if (isClosed) return null;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearQrLoading: true,
          qrError: _message(e),
        ),
      );
      return null;
    }
  }

  /// Destructive: every previously printed card for this table dies.
  Future<PanelTableQr?> rotateQr(String tableId) async {
    final s = state;
    if (s is! TablesPanelLoaded) return null;
    emit(s.copyWith(qrLoadingId: tableId, clearQrError: true));
    try {
      final qr = await _repo.rotateTableQr(
        restaurantId: restaurantId,
        tableId: tableId,
      );
      if (isClosed) return null;
      final now = state as TablesPanelLoaded;
      emit(now.copyWith(qr: {...now.qr, tableId: qr}, clearQrLoading: true));
      return qr;
    } catch (e) {
      if (isClosed) return null;
      emit(
        (state as TablesPanelLoaded).copyWith(
          clearQrLoading: true,
          qrError: _message(e),
        ),
      );
      return null;
    }
  }

  void clearActionError() {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    if (s.actionError == null) return;
    emit(s.copyWith(clearError: true));
  }

  void _patch(PanelPhysicalTable updated) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(
      s.copyWith(
        tables: [
          for (final t in s.tables)
            if (t.id == updated.id) updated else t,
        ],
        clearAction: true,
        clearError: true,
      ),
    );
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
