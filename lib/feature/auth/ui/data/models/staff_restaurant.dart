/// A restaurant the logged-in user serves as staff (owner / manager / staff),
/// as returned by `restaurant-login` and `verify-restaurant-otp`.
class StaffRestaurant {
  final String restaurantId;
  final String name;
  final String nameEn;
  final String nameAr;
  final String role;
  final List<String> permissions;
  final String status;

  const StaffRestaurant({
    this.restaurantId = '',
    this.name = '',
    this.nameEn = '',
    this.nameAr = '',
    this.role = '',
    this.permissions = const [],
    this.status = '',
  });

  /// True for roles allowed to manage the venue (mirrors the backend's
  /// `isRestaurantOwner` derivation: owner or manager).
  bool get isManager => role == 'owner' || role == 'manager';

  /// UI gating: owner/manager (and anyone holding full_access) may manage
  /// venue content; plain staff operate (status actions, read-only views).
  bool get canManage =>
      role == 'owner' ||
      role == 'manager' ||
      permissions.contains('full_access');

  String displayName(String locale) {
    if (locale == 'ar') return nameAr.isNotEmpty ? nameAr : nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  factory StaffRestaurant.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const StaffRestaurant();
    return StaffRestaurant(
      restaurantId: json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      nameAr: json['nameAr']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'role': role,
      'permissions': permissions,
      'status': status,
    };
  }
}
