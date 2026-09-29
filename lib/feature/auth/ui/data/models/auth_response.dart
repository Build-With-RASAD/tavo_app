import 'staff_restaurant.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? token;
  final UserData? user;

  /// Staff flow only: set by `restaurant-login` / `verify-restaurant-otp`.
  final bool hasRestaurantAccess;
  final List<StaffRestaurant> restaurants;
  final bool isRestaurantOwner;

  AuthResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
    this.hasRestaurantAccess = false,
    this.restaurants = const [],
    this.isRestaurantOwner = false,
  });

  factory AuthResponse.fromJson(dynamic json) {
    if (json is String) {
      return AuthResponse(
        success: false,
        message: json,
      );
    }
    
    if (json is! Map<String, dynamic>) {
      return AuthResponse(
        success: false,
        message: 'Invalid response format',
      );
    }

    return AuthResponse(
      success: json['success'] ?? json['status'] == true || json['status'] == 'success',
      message: json['message']?.toString(),
      token: json['token']?.toString() ?? json['data']?['token']?.toString(),
      user: json['user'] != null 
          ? UserData.fromJson(json['user']) 
          : json['data']?['user'] != null 
              ? UserData.fromJson(json['data']['user'])
              : null,
      hasRestaurantAccess: json['hasRestaurantAccess'] == true,
      restaurants: (json['restaurants'] as List<dynamic>?)
              ?.map(StaffRestaurant.fromJson)
              .toList() ??
          const [],
      isRestaurantOwner: json['isRestaurantOwner'] == true,
    );
  }
}

class UserData {
  final String? id;
  final String? name;
  final String? phone;
  final String? email;
  final String? countryCode;

  UserData({
    this.id,
    this.name,
    this.phone,
    this.email,
    this.countryCode,
  });

  factory UserData.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return UserData();
    }
    
    return UserData(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      countryCode: json['countryCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'countryCode': countryCode,
    };
  }
}