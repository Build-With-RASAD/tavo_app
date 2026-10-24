// lib/feature/kitchen/ui/logic/kitchen_cubit.dart
//
// Kitchen display (Task 46). The board is a poll-driven view over the existing
// panel orders endpoint: no new backend, no push channel, and the same
// transition rules the order cards already use.
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../restaurant_panel/data/model/panel_order.dart';
import '../../../restaurant_panel/data/repo/restaurant_panel_repo.dart';

sealed class KitchenState {
  const KitchenState();
}

class KitchenLoading extends KitchenState {
  const KitchenLoading();
}

class KitchenFailure extends KitchenState {
  const KitchenFailure(this.message);
  final String message;
}

class KitchenBoard extends KitchenState {
  const KitchenBoard({
    required this.orders,
    this.updatingId,
    this.actionError,
  });

  final List<PanelOrder> orders;

  /// The order whose status is being patched, so its card can show a spinner.
  final String? updatingId;
  final String? actionError;

  static const Set<String> _incomingStatuses = {'pending', 'confirmed'};

  List<PanelOrder> get incoming => _where(_incomingStatuses);
  List<PanelOrder> get preparing => _where(const {'preparing'});
  List<PanelOrder> get ready => _where(const {'ready'});

  List<PanelOrder> _where(Set<String> statuses) => orders
      .where((order) => statuses.contains(order.orderStatus))
      .toList(growable: false);

  KitchenBoard copyWith({
    List<PanelOrder>? orders,
    String? updatingId,
    String? actionError,
    bool clearUpdating = false,
    bool clearError = false,
  }) => KitchenBoard(
    orders: orders ?? this.orders,
    updatingId: clearUpdating ? null : (updatingId ?? this.updatingId),
    actionError: clearError ? null : (actionError ?? this.actionError),
  );
}

/// One tap in the kitchen walks an order to the next station. `pending` is the
/// exception: the backend requires it to be confirmed before it can be cooked,
/// so "start" sends both stamps back to back.
const Map<String, List<String>> _kitchenPath = {
  'pending': ['confirmed', 'preparing'],
  'confirmed': ['preparing'],
  'preparing': ['ready'],
  'ready': ['served'],
};

class KitchenCubit extends Cubit<KitchenState> {
  KitchenCubit(this._repo, {required this.restaurantId})
    : super(const KitchenLoading());

  final RestaurantPanelRepo _repo;
  final String restaurantId;

  Timer? _timer;
  bool _loading = false;

  /// Loads once and then refreshes every [pollInterval] until [close].
  Future<void> start({
    Duration pollInterval = const Duration(seconds: 15),
  }) async {
    await load();
    _timer ??= Timer.periodic(pollInterval, (_) => load(silent: true));
  }

  Future<void> load({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent) emit(const KitchenLoading());

    try {
      final page = await _repo.getOrders(restaurantId, limit: 50);
      final active = page.items
          .where((order) => _kitchenPath.containsKey(order.orderStatus))
          .toList(growable: false);
      if (isClosed) return;
      emit(KitchenBoard(orders: active));
    } catch (error) {
      if (isClosed) return;
      final current = state;
      if (current is KitchenBoard) {
        emit(current.copyWith(actionError: '$error'));
      } else {
        emit(KitchenFailure('$error'));
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> advance(PanelOrder order) async {
    final path = _kitchenPath[order.orderStatus];
    if (path == null) return;

    final current = state;
    if (current is! KitchenBoard || current.updatingId != null) return;

    emit(current.copyWith(updatingId: order.id, clearError: true));
    try {
      for (final status in path) {
        await _repo.updateOrderStatus(
          restaurantId: restaurantId,
          id: order.id,
          status: status,
        );
      }
      final board = state;
      if (board is KitchenBoard) emit(board.copyWith(clearUpdating: true));
      await load(silent: true);
    } catch (error) {
      final board = state;
      if (board is KitchenBoard) {
        emit(
          board.copyWith(updatingId: null, actionError: '$error', clearUpdating: true),
        );
      }
    }
  }

  void clearError() {
    final current = state;
    if (current is KitchenBoard) emit(current.copyWith(clearError: true));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
