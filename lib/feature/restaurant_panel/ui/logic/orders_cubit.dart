import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';

import 'orders_state.dart';

/// Staff panel's order list: status filter, page-append pagination and
/// per-row status actions.
///
/// Error style mirrors `RestaurantAuthCubit` (plain strings). Loading rules:
/// `load` emits [OrdersLoading] only when there is no list yet (or on an
/// explicit `refresh`), `loadMore` never emits Loading — it appends behind
/// the visible list and reports failures through `actionError`.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._repo, {required this.restaurantId})
      : super(OrdersInitial());

  final RestaurantPanelRepo _repo;
  final String restaurantId;

  /// Current status filter (`null` = all) — kept across loads.
  String? _filter;

  /// Re-entrancy guard for `loadMore`, which has no Loading state to hide
  /// behind.
  bool _loadingMore = false;

  /// Loads page 1 and replaces the list. Emits [OrdersLoading] only when the
  /// list is not already visible (first load / after error) or [refresh] is
  /// requested.
  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    if (refresh || state is! OrdersLoaded) emit(OrdersLoading());
    try {
      final result =
          await _repo.getOrders(restaurantId, page: 1, status: _filter);
      if (isClosed) return;
      emit(OrdersLoaded(
        orders: result.items,
        filter: _filter,
        page: result.page,
        pages: result.pages,
        hasNext: result.hasNext,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(OrdersError(_message(e)));
    }
  }

  /// Appends the next page behind the visible list. No-op when there is no
  /// loaded list, no next page, or another `loadMore` is in flight.
  Future<void> loadMore() async {
    if (isClosed || _loadingMore) return;
    final current = state;
    if (current is! OrdersLoaded || !current.hasNext) return;

    _loadingMore = true;
    try {
      final result = await _repo.getOrders(
        restaurantId,
        page: current.page + 1,
        status: _filter,
      );
      if (isClosed) return;
      emit(OrdersLoaded(
        orders: [...current.orders, ...result.items],
        filter: current.filter,
        page: result.page,
        pages: result.pages,
        hasNext: result.hasNext,
        actingId: current.actingId,
        actionError: current.actionError,
      ));
    } catch (e) {
      if (isClosed) return;
      // Pagination failure is non-fatal: keep every row on screen.
      emit(OrdersLoaded(
        orders: current.orders,
        filter: current.filter,
        page: current.page,
        pages: current.pages,
        hasNext: current.hasNext,
        actingId: current.actingId,
        actionError: _message(e),
      ));
    } finally {
      _loadingMore = false;
    }
  }

  /// Applies the status filter (`null` = all) and reloads page 1.
  Future<void> setFilter(String? status) async {
    _filter = status;
    await load();
  }

  /// Runs a status action for one row: marks `actingId`, then swaps in the
  /// server-returned order on success or surfaces `actionError` on failure.
  /// No-op unless the list is loaded.
  Future<void> updateStatus(String id, String status) async {
    final current = state;
    if (current is! OrdersLoaded || isClosed) return;
    emit(OrdersLoaded(
      orders: current.orders,
      filter: current.filter,
      page: current.page,
      pages: current.pages,
      hasNext: current.hasNext,
      actingId: id,
    ));
    try {
      final updated = await _repo.updateOrderStatus(
        restaurantId: restaurantId,
        id: id,
        status: status,
      );
      if (isClosed) return;
      emit(OrdersLoaded(
        orders: [for (final o in current.orders) o.id == id ? updated : o],
        filter: current.filter,
        page: current.page,
        pages: current.pages,
        hasNext: current.hasNext,
      ));
    } catch (e) {
      if (isClosed) return;
      // Action failure is non-fatal: every row stays, the message surfaces
      // beside the list.
      emit(OrdersLoaded(
        orders: current.orders,
        filter: current.filter,
        page: current.page,
        pages: current.pages,
        hasNext: current.hasNext,
        actionError: _message(e),
      ));
    }
  }

  String _message(dynamic error) =>
      error is String ? error : error.toString();
}
