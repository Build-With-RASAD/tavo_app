import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

/// States of the staff panel's order list.
///
/// Mirrors `RestaurantAuthState`: plain classes, plain-string errors.
abstract class OrdersState {}

class OrdersInitial extends OrdersState {}

class OrdersLoading extends OrdersState {}

class OrdersLoaded extends OrdersState {
  OrdersLoaded({
    required this.orders,
    this.filter,
    required this.page,
    required this.pages,
    required this.hasNext,
    this.actingId,
    this.actionError,
  });

  /// The visible list — page 1 alone or the concatenation of every page
  /// loaded so far.
  final List<PanelOrder> orders;

  /// Status filter passed to the repo; `null` = all orders.
  final String? filter;

  /// Current (last) page number, 1-based.
  final int page;

  /// Total pages reported by the server.
  final int pages;

  /// Whether a page after [page] exists — guards `loadMore`.
  final bool hasNext;

  /// Id of the row currently running a status action, if any.
  final String? actingId;

  /// Non-fatal action/pagination error; the list stays visible.
  final String? actionError;
}

class OrdersError extends OrdersState {
  OrdersError(this.message);

  final String message;
}
