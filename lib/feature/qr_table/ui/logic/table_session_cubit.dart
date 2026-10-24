// lib/feature/qr_table/ui/logic/table_session_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/table_session_models.dart';
import '../../data/repo/qr_table_repo.dart';

sealed class TableSessionState {
  const TableSessionState();
}

class TableSessionLoading extends TableSessionState {
  const TableSessionLoading();
}

class TableSessionReady extends TableSessionState {
  const TableSessionReady({
    required this.context,
    required this.snapshot,
    this.cart = const {},
    this.placing = false,
    this.rating = false,
    this.actionError,
  });

  final TableContext context;
  final TableSnapshot snapshot;
  final Map<String, TableCartLine> cart;
  final bool placing;
  final bool rating;
  final String? actionError;

  bool get isCartEmpty => cart.isEmpty;
  int get cartCount =>
      cart.values.fold(0, (sum, line) => sum + line.quantity);
  double get cartTotal =>
      cart.values.fold(0, (sum, line) => sum + line.lineTotal);

  List<TableOrder> get activeOrders =>
      snapshot.orders.where((order) => order.isActive).toList(growable: false);

  List<TableOrder> get pastOrders =>
      snapshot.orders.where((order) => !order.isActive).toList(growable: false);

  TableSessionReady copyWith({
    TableContext? context,
    TableSnapshot? snapshot,
    Map<String, TableCartLine>? cart,
    bool? placing,
    bool? rating,
    String? actionError,
    bool clearError = false,
  }) =>
      TableSessionReady(
        context: context ?? this.context,
        snapshot: snapshot ?? this.snapshot,
        cart: cart ?? this.cart,
        placing: placing ?? this.placing,
        rating: rating ?? this.rating,
        actionError: clearError ? null : (actionError ?? this.actionError),
      );
}

class TableSessionFailure extends TableSessionState {
  const TableSessionFailure(this.message);
  final String message;
}

/// Owns one table visit: resolve → join/resume → shared orders → rating.
///
/// The guest token is persisted per QR token, so closing the app does not turn
/// one diner into two covers. Every network failure keeps the last good view on
/// screen; only the first load can replace the screen with an error.
class TableSessionCubit extends Cubit<TableSessionState> {
  TableSessionCubit(this._repo, this._store, {required this.qrToken})
      : super(const TableSessionLoading());

  final QrTableRepo _repo;
  final TableGuestStore _store;
  final String qrToken;

  String? _guestToken;

  Future<void> open() async {
    emit(const TableSessionLoading());
    try {
      final context = await _repo.resolve(qrToken);

      final savedToken = await _store.read(qrToken);
      if (savedToken != null && savedToken.isNotEmpty) {
        try {
          final snapshot = await _repo.state(savedToken);
          _guestToken = savedToken;
          emit(TableSessionReady(context: context, snapshot: snapshot));
          return;
        } catch (_) {
          // The session was closed or the token was rotated: fall through and
          // join as a new guest rather than showing a dead table.
          await _store.clear();
        }
      }

      final joined = await _repo.join(qrToken);
      _guestToken = joined.guestToken;
      await _store.write(qrToken, joined.guestToken);

      final snapshot = await _repo.state(joined.guestToken);
      emit(TableSessionReady(context: context, snapshot: snapshot));
    } catch (error) {
      emit(TableSessionFailure('$error'));
    }
  }

  /// Silent live refresh. Never downgrades a working screen to an error.
  Future<void> refresh() async {
    final current = state;
    final token = _guestToken;
    if (current is! TableSessionReady || token == null) return;

    try {
      final snapshot = await _repo.state(token);
      if (isClosed) return;
      emit(current.copyWith(snapshot: snapshot));
    } catch (_) {
      // Polling failure is transient; keep the last known state.
    }
  }

  void addItem({required String id, required String name, required double price}) {
    final current = state;
    if (current is! TableSessionReady || !current.snapshot.canOrder) return;

    final existing = current.cart[id];
    final next = Map<String, TableCartLine>.from(current.cart);
    next[id] = existing == null
        ? TableCartLine(
            menuItemId: id,
            name: name,
            unitPrice: price,
            quantity: 1,
          )
        : existing.copyWith(quantity: existing.quantity + 1);

    emit(current.copyWith(cart: next, clearError: true));
  }

  void decrementItem(String id) {
    final current = state;
    if (current is! TableSessionReady) return;

    final existing = current.cart[id];
    if (existing == null) return;

    final next = Map<String, TableCartLine>.from(current.cart);
    if (existing.quantity <= 1) {
      next.remove(id);
    } else {
      next[id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    emit(current.copyWith(cart: next, clearError: true));
  }

  void clearCart() {
    final current = state;
    if (current is! TableSessionReady) return;
    emit(current.copyWith(cart: const {}, clearError: true));
  }

  Future<bool> placeOrder({String notes = ''}) async {
    final current = state;
    final token = _guestToken;
    if (current is! TableSessionReady || token == null || current.isCartEmpty) {
      return false;
    }

    emit(current.copyWith(placing: true, clearError: true));
    try {
      await _repo.placeOrder(token, current.cart.values.toList(), notes: notes);
      final snapshot = await _repo.state(token);
      if (isClosed) return true;
      emit(current.copyWith(
        snapshot: snapshot,
        cart: const {},
        placing: false,
      ));
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(current.copyWith(placing: false, actionError: '$error'));
      return false;
    }
  }

  Future<bool> submitRating(RatingDraft draft) async {
    final current = state;
    final token = _guestToken;
    if (current is! TableSessionReady || token == null) return false;

    emit(current.copyWith(rating: true, clearError: true));
    try {
      await _repo.submitRating(token, draft);
      final snapshot = await _repo.state(token);
      if (isClosed) return true;
      emit(current.copyWith(snapshot: snapshot, rating: false));
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(current.copyWith(rating: false, actionError: '$error'));
      return false;
    }
  }

  void clearError() {
    final current = state;
    if (current is TableSessionReady) {
      emit(current.copyWith(clearError: true));
    }
  }
}
