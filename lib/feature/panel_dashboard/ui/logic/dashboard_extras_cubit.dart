// lib/feature/panel_dashboard/ui/logic/dashboard_extras_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/dashboard_panel_repo.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'dashboard_extras_state.dart';

export 'dashboard_extras_state.dart';

/// Rich dashboard extras: floor occupancy, waitlist preview, orders summary.
///
/// One [load] fans out to the three reads with [Future.wait]; occupancy is
/// derived client-side (open order ⟺ [DashboardOpenOrder.isOpen] with a
/// matching tableId) so the physical `status` field is never rewritten.
/// Load failures emit [DashboardExtrasError] (retry calls [load] again);
/// walk-in failures keep the loaded content and surface
/// [DashboardExtrasLoaded.actionError] beside it.
class DashboardExtrasCubit extends Cubit<DashboardExtrasState> {
  DashboardExtrasCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const DashboardExtrasInitial());

  final DashboardPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const DashboardExtrasLoading());
    try {
      final tablesFuture = _repo.getFloorTables(restaurantId);
      final previewFuture = _repo.getWaitlistPreview(restaurantId);
      final ordersFuture = _repo.getOpenOrders(restaurantId);
      final results = await Future.wait([
        tablesFuture,
        previewFuture,
        ordersFuture,
      ]);
      if (isClosed) return;
      final tables = results[0] as List<PanelPhysicalTable>;
      final preview =
          results[1] as ({List<PanelWaitlistEntry> entries, int total});
      final orders = results[2] as List<DashboardOpenOrder>;
      emit(_loaded(tables: tables, preview: preview, orders: orders));
    } catch (e) {
      if (isClosed) return;
      emit(DashboardExtrasError(_message(e)));
    }
  }

  DashboardExtrasLoaded _loaded({
    required List<PanelPhysicalTable> tables,
    required ({List<PanelWaitlistEntry> entries, int total}) preview,
    required List<DashboardOpenOrder> orders,
  }) {
    final occupiedIds = {
      for (final o in orders)
        if (o.isOpen && o.tableId.isNotEmpty) o.tableId,
    };
    final ordersByStatus = <String, int>{};
    for (final o in orders) {
      ordersByStatus[o.orderStatus] = (ordersByStatus[o.orderStatus] ?? 0) + 1;
    }
    return DashboardExtrasLoaded(
      tables: tables,
      occupiedIds: occupiedIds,
      waitlist: preview.entries,
      waitlistTotal: preview.total,
      ordersByStatus: ordersByStatus,
    );
  }

  /// Staff walk-in: POSTs through the repo, then refreshes the preview page.
  /// Failures keep the loaded content with [actionError] beside it.
  Future<void> addToWaitlist({
    required int guestsCount,
    required String name,
    required String phone,
    String? email,
    String? specialRequests,
  }) async {
    final s = state;
    if (s is! DashboardExtrasLoaded) return;
    emit(s.copyWith(clearError: true));
    try {
      await _repo.createWaitlistEntry(
        restaurantId: restaurantId,
        guestsCount: guestsCount,
        name: name,
        phone: phone,
        email: email,
        specialRequests: specialRequests,
      );
      if (isClosed) return;
      final preview = await _repo.getWaitlistPreview(restaurantId);
      if (isClosed) return;
      emit(s.copyWith(
        waitlist: preview.entries,
        waitlistTotal: preview.total,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e)));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
