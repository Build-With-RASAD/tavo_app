import 'package:tavo/feature/booking/data/model/booking_model.dart';

abstract class RestaurantHomeState {}

class RestaurantHomeInitial extends RestaurantHomeState {}

class RestaurantHomeLoading extends RestaurantHomeState {}

class RestaurantHomeLoaded extends RestaurantHomeState {
  final List<BookingModel> reservations;

  /// Row currently executing a status action (button spinner).
  final String? actingId;

  /// Non-fatal error from the last action; the list stays visible.
  final String? actionError;

  RestaurantHomeLoaded(this.reservations, {this.actingId, this.actionError});
}

class RestaurantHomeError extends RestaurantHomeState {
  final String message;
  RestaurantHomeError(this.message);
}
