import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'restaurant_home_state.dart';

/// Venue reservations for one staff restaurant: load + status actions
/// (confirm → seat → complete, cancellable while pending/confirmed).
/// Wave 1 Task 13: reads the PANEL reservations endpoints through
/// [RestaurantPanelRepo]; the public constructor shape and the
/// `loadReservations` / `updateStatus` names are unchanged so
/// `ReservationsTab` and its tests do not change.
/// A failed action keeps the list and surfaces
/// [RestaurantHomeLoaded.actionError] instead of wiping the screen.
class RestaurantHomeCubit extends Cubit<RestaurantHomeState> {
  final RestaurantPanelRepo _repo;
  final String restaurantId;

  RestaurantHomeCubit(this._repo, {required this.restaurantId})
      : super(RestaurantHomeInitial());

  Future<void> loadReservations() async {
    if (isClosed) return;
    emit(RestaurantHomeLoading());
    try {
      final reservations = await _repo.getReservations(restaurantId);
      if (isClosed) return;
      emit(RestaurantHomeLoaded(reservations));
    } catch (e) {
      if (isClosed) return;
      emit(RestaurantHomeError(_message(e)));
    }
  }

  Future<void> updateStatus(String id, String action) async {
    final current = state;
    if (current is! RestaurantHomeLoaded || isClosed) return;
    emit(
      RestaurantHomeLoaded(
        current.reservations,
        actingId: id,
      ),
    );
    try {
      final updated = await _repo.updateReservationAction(
        restaurantId: restaurantId,
        id: id,
        action: action,
        reason: action == 'cancel' ? 'Cancelled by restaurant' : null,
      );
      if (isClosed) return;
      emit(
        RestaurantHomeLoaded([
          for (final b in current.reservations)
            b.id == id ? updated : b,
        ]),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        RestaurantHomeLoaded(
          current.reservations,
          actionError: _message(e),
        ),
      );
    }
  }

  String _message(dynamic error) =>
      error is String ? error : error.toString();
}

/// Status → next staff actions, mirroring the backend lifecycle
/// (pending → confirmed → seated → completed, cancellable while pending/confirmed).
List<String> nextActionsFor(String status) {
  switch (status) {
    case 'pending':
      return ['confirm', 'cancel'];
    case 'confirmed':
      return ['seat', 'cancel'];
    case 'seated':
      return ['complete'];
    case 'finished_meal':
      return ['complete'];
    default:
      return [];
  }
}

/// Button label per action (localized at the call site via `.tr()` keys).
String actionLabelKey(String action) {
  switch (action) {
    case 'confirm':
      return 'confirm';
    case 'seat':
      return 'seat';
    case 'complete':
      return 'complete';
    case 'cancel':
      return 'cancel';
    default:
      return action;
  }
}
