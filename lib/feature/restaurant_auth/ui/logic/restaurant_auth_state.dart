import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

abstract class RestaurantAuthState {}

class RestaurantAuthInitial extends RestaurantAuthState {}

class RestaurantAuthLoading extends RestaurantAuthState {}

class RestaurantOtpSent extends RestaurantAuthState {
  final String phone;
  final String countryCode;
  final List<StaffRestaurant> restaurants;

  RestaurantOtpSent({
    required this.phone,
    required this.countryCode,
    this.restaurants = const [],
  });
}

class RestaurantAuthenticated extends RestaurantAuthState {
  final List<StaffRestaurant> restaurants;
  final bool isOwner;

  RestaurantAuthenticated({
    this.restaurants = const [],
    this.isOwner = false,
  });
}

class RestaurantAuthError extends RestaurantAuthState {
  final String message;
  RestaurantAuthError(this.message);
}
