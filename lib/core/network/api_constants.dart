class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://46.202.134.87:4321';
  static const String register = '/v1/api/auth/register';
  static const String login = '/v1/api/auth/login';
  static const String verifyOtp = '/v1/api/auth/verify-otp';
  static const String restaurantLogin = '/v1/api/auth/restaurant-login';
  static const String verifyRestaurantOtp = '/v1/api/auth/verify-restaurant-otp';
  static String restaurantReservations(String restaurantId) =>
      '/v1/api/reservation/restaurant/$restaurantId';
  static String reservationAction(String id, String action) =>
      '/v1/api/reservation/$id/$action';
  static const String home = '/v1/api/home';
  static const String restaurants = '/v1/api/restaurant';
  static String restaurantDetails(String id) => '/v1/api/restaurant/$id';
  static String restaurantMenu(String id) => '/v1/api/menu-item/$id/';
  static const String profile = '/v1/api/me/profile';
  static const String uploadAvatar = '/v1/api/me/avatar/upload';
  static const String userStats = '/v1/api/me/stats';
  static const String myReservations = '/v1/api/reservation/my';
  static String reservationDetails(String id) => '/v1/api/reservation/$id';
  static const String createReservation = '/v1/api/reservation';
  static String checkAvailability(
    String restaurantId,
    String date,
    String time,
  ) => '/v1/api/availability/restaurant/$restaurantId/$date/$time';
}
