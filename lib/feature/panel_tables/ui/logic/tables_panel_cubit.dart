// ui/logic/tables_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/table_models.dart';
import '../../data/repo/tables_panel_repo.dart';

part 'tables_panel_state.dart';

/// Staff panel floor editor: table-type chips, the fractional `[0,1]`
/// floor-plan canvas (local moves, persisted on save), per-table status
/// toggles and — since the T28 redesign — create/update/delete + bulk
/// zone/status mutations.
///
/// Error style mirrors `PanelMenuCubit` (plain strings): `load` failures emit
/// [TablesPanelError]; mutation failures keep the loaded state and surface a
/// transient [TablesPanelLoaded.actionError] beside it.
class TablesPanelCubit extends Cubit<TablesPanelState> {
  TablesPanelCubit(this._repo, {required this.restaurantId})
      : super(const TablesPanelInitial());

  final TablesPanelRepo _repo;
  final String restaurantId;

  /// Loads the types, auto-selects the first one and fetches its tables.
  Future<void> load() async {
    if (isClosed) return;
    emit(const TablesPanelLoading());
    try {
      final types = await _repo.getTableTypes(restaurantId);
      if (isClosed) return;
      if (types.isEmpty) {
        emit(const TablesPanelLoaded(types: [], tables: []));
        return;
      }
      final selected = types.first.id;
      final tables =
          await _repo.getPhysicalTables(restaurantId, selected);
      if (isClosed) return;
      emit(TablesPanelLoaded(
        types: types,
        selectedTypeId: selected,
        tables: tables,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(TablesPanelError(_message(e)));
    }
  }

  Future<void> selectType(String id) async {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(selectedTypeId: id, clearError: true));
    try {
      final tables = await _repo.getPhysicalTables(restaurantId, id);
      if (isClosed) return;
      emit(s.copyWith(
        selectedTypeId: id,
        tables: tables,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Edit-mode snap-to-grid: rounds a fraction to the nearest 0.05 step
  /// (spec decision 1 — exact, two-decimal values, no float dust).
  static double snapToGrid(double v) =>
      double.parse(((v / 0.05).round() * 0.05).toStringAsFixed(2));

  /// Local-only move, clamped to the `[0,1]` editor box. Persisted on save.
  /// [snap] rounds to the 0.05 grid first (edit mode's snap toggle).
  void moveTable(String id, double x, double y, {bool snap = false}) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    final fx = snap ? snapToGrid(x) : x;
    final fy = snap ? snapToGrid(y) : y;
    emit(s.copyWith(
      tables: [
        for (final t in s.tables)
          if (t.id == id)
            t.copyWith(x: fx.clamp(0.0, 1.0), y: fy.clamp(0.0, 1.0))
          else
            t,
      ],
    ));
  }

  /// Persists every table's fractional position to `PUT /floor-plan`.
  /// Failures keep the positions and surface `actionError`.
  Future<void> saveFloorPlan() async {
    final s = state;
    if (s is! TablesPanelLoaded || s.saving) return;
    emit(s.copyWith(saving: true, clearError: true));
    try {
      await _repo.saveFloorPlan(
        restaurantId,
        [for (final t in s.tables) (id: t.id, x: t.x, y: t.y)],
      );
      if (isClosed) return;
      emit(s.copyWith(saving: false));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(saving: false, actionError: _message(e)));
    }
  }

  /// Cycles `available ↔ unavailable`; failures keep the row.
  Future<void> toggleStatus(PanelPhysicalTable table) async {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(actionId: table.id, clearError: true));
    try {
      final next =
          table.status == 'available' ? 'unavailable' : 'available';
      final updated = await _repo.updatePhysicalTableStatus(
          restaurantId: restaurantId, id: table.id, status: next);
      if (isClosed) return;
      emit(s.copyWith(
        tables: [
          for (final t in s.tables) if (t.id == table.id) updated else t
        ],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// POST /tables/:tableTypeId/physical for the selected type (T28).
  /// Returns `true` when the table was created.
  Future<bool> createTable({
    required String code,
    required int seats,
    String? zone,
  }) async {
    final s = state;
    if (s is! TablesPanelLoaded || s.creating) return false;
    final typeId = s.selectedTypeId;
    if (typeId == null) return false;
    emit(s.copyWith(creating: true, clearError: true));
    try {
      final created = await _repo.createPhysicalTable(
        restaurantId: restaurantId,
        tableTypeId: typeId,
        code: code,
        seats: seats,
        zone: zone,
      );
      if (isClosed) return false;
      final base = _loaded(s);
      emit(base.copyWith(
        tables: [...base.tables, created],
        creating: false,
        clearError: true,
      ));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(_loaded(s).copyWith(creating: false, actionError: _message(e)));
      return false;
    }
  }

  /// PUT /physical-tables/:id — code/seats/zone edit from the detail sheet.
  /// Returns `true` when the table was updated.
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
      final base = _loaded(s);
      emit(base.copyWith(
        tables: [
          for (final t in base.tables) if (t.id == id) updated else t
        ],
        clearAction: true,
        clearError: true,
      ));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(_loaded(s).copyWith(clearAction: true, actionError: _message(e)));
      return false;
    }
  }

  /// DELETE /physical-tables/:id — the backend's 409 blockers (open order /
  /// active reservation) surface as [TablesPanelLoaded.actionError].
  /// Returns `true` when the table was deleted.
  Future<bool> deleteTable(String id) async {
    final s = state;
    if (s is! TablesPanelLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      await _repo.deletePhysicalTable(restaurantId: restaurantId, id: id);
      if (isClosed) return false;
      final base = _loaded(s);
      emit(base.copyWith(
        tables: [for (final t in base.tables) if (t.id != id) t],
        clearAction: true,
        clearError: true,
      ));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(_loaded(s).copyWith(clearAction: true, actionError: _message(e)));
      return false;
    }
  }

  /// Multi-select bulk: assign the same zone to every selected table (T28 §8).
  Future<void> bulkSetZone(List<String> ids, String zone) =>
      _bulk(ids, (id) => _repo.updatePhysicalTable(
            restaurantId: restaurantId,
            id: id,
            zone: zone,
          ));

  /// Multi-select bulk: set the same status on every selected table (T28 §8).
  Future<void> bulkSetStatus(List<String> ids, String status) =>
      _bulk(ids, (id) => _repo.updatePhysicalTableStatus(
            restaurantId: restaurantId,
            id: id,
            status: status,
          ));

  Future<void> _bulk(
    List<String> ids,
    Future<PanelPhysicalTable> Function(String id) run,
  ) async {
    final s = state;
    if (s is! TablesPanelLoaded || ids.isEmpty) return;
    emit(s.copyWith(actionId: ids.first, clearError: true));
    try {
      for (final id in ids) {
        final updated = await run(id);
        if (isClosed) return;
        final base = _loaded(s);
        emit(base.copyWith(
          tables: [
            for (final t in base.tables) if (t.id == id) updated else t
          ],
        ));
      }
      if (isClosed) return;
      emit(_loaded(s).copyWith(clearAction: true, clearError: true));
    } catch (e) {
      if (isClosed) return;
      emit(_loaded(s).copyWith(clearAction: true, actionError: _message(e)));
    }
  }

  TablesPanelLoaded _loaded(TablesPanelLoaded fallback) =>
      state is TablesPanelLoaded ? state as TablesPanelLoaded : fallback;

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
