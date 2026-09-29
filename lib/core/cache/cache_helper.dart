import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  CacheHelper._();

  static SharedPreferences? _prefs;

  static const String _tokenKey = 'token';
  static const String _userKey = 'user';
  static const String _phoneKey = 'phone';
  static const String _countryCodeKey = 'country_code';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userImageKey = 'user_image';
  static const String _staffModeKey = 'staff_mode';
  static const String _staffRestaurantsKey = 'staff_restaurants';
  static const String _activeRestaurantKey = 'active_restaurant_id';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<bool> setToken(String token) async {
    return await _prefs?.setString(_tokenKey, token) ?? false;
  }

  static String? getToken() {
    return _prefs?.getString(_tokenKey);
  }

  static Future<bool> setUserId(String id) async {
    return await _prefs?.setString(_userIdKey, id) ?? false;
  }

  static String? getUserId() {
    return _prefs?.getString(_userIdKey);
  }

  static Future<bool> setUserName(String name) async {
    return await _prefs?.setString(_userNameKey, name) ?? false;
  }

  static String? getUserName() {
    return _prefs?.getString(_userNameKey);
  }

  static Future<bool> setUserImage(String url) async {
    return await _prefs?.setString(_userImageKey, url) ?? false;
  }

  static String? getUserImage() {
    return _prefs?.getString(_userImageKey);
  }

  static Future<bool> setPhone(String phone) async {
    return await _prefs?.setString(_phoneKey, phone) ?? false;
  }

  static String? getPhone() {
    return _prefs?.getString(_phoneKey);
  }

  static Future<bool> setCountryCode(String code) async {
    return await _prefs?.setString(_countryCodeKey, code) ?? false;
  }

  static String? getCountryCode() {
    return _prefs?.getString(_countryCodeKey);
  }

  static Future<bool> setUser(String userJson) async {
    return await _prefs?.setString(_userKey, userJson) ?? false;
  }

  static String? getUser() {
    return _prefs?.getString(_userKey);
  }

  static Future<bool> setOnboardingCompleted(bool value) async {
    return await _prefs?.setBool(_onboardingKey, value) ?? false;
  }

  static bool isOnboardingCompleted() {
    return _prefs?.getBool(_onboardingKey) ?? false;
  }

  static Future<bool> clearAll() async {
    return await _prefs?.clear() ?? false;
  }

  static Future<bool> clearUserData() async {
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_phoneKey);
    await _prefs?.remove(_countryCodeKey);
    await _prefs?.remove(_userIdKey);
    await _prefs?.remove(_userNameKey);
    await _prefs?.remove(_userImageKey);
    await _prefs?.remove(_staffModeKey);
    await _prefs?.remove(_staffRestaurantsKey);
    await _prefs?.remove(_activeRestaurantKey);
    return true;
  }

  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  /// True when the active session belongs to restaurant staff (as opposed to
  /// a customer). Survives restarts so splash can route back to staff home.
  static Future<bool> setStaffMode(bool value) async {
    return await _prefs?.setBool(_staffModeKey, value) ?? false;
  }

  static bool isStaffMode() {
    return _prefs?.getBool(_staffModeKey) ?? false;
  }

  static Future<bool> setStaffRestaurants(String restaurantsJson) async {
    return await _prefs?.setString(_staffRestaurantsKey, restaurantsJson) ??
        false;
  }

  static String? getStaffRestaurants() {
    return _prefs?.getString(_staffRestaurantsKey);
  }

  static Future<bool> setActiveRestaurant(String id) async {
    return await _prefs?.setString(_activeRestaurantKey, id) ?? false;
  }

  static String? getActiveRestaurant() {
    return _prefs?.getString(_activeRestaurantKey);
  }
}