// ui/logic/tables_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/table_models.dart';
import '../../data/repo/tables_panel_repo.dart';

part 'tables_panel_state.dart';

/// Staff panel floor editor: table-type chips, the fractional `[0,1]`
/// floor-plan canvas (local moves, persisted on save), and per-table status
/// toggles.
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

  /// Local-only move, clamped to the `[0,1]` editor box. Persisted on save.
  void moveTable(String id, double x, double y) {
    final s = state;
    if (s is! TablesPanelLoaded) return;
    emit(s.copyWith(
      tables: [
        for (final t in s.tables)
          if (t.id == id)
            PanelPhysicalTable(
              id: t.id,
              tableTypeId: t.tableTypeId,
              code: t.code,
              seats: t.seats,
              status: t.status,
              x: x.clamp(0.0, 1.0),
              y: y.clamp(0.0, 1.0),
            )
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

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
