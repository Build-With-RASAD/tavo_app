// lib/feature/panel_customers/data/model/customer_models.dart
class PanelCustomer {
  const PanelCustomer({
    required this.key,
    required this.name,
    required this.phone,
    required this.orderCount,
    required this.reservationCount,
    required this.totalSpent,
    this.email,
    this.lastOrderAt,
  });

  final String key;
  final String name;
  final String phone;
  final int orderCount;
  final int reservationCount;
  final double totalSpent;
  final String? email;
  final String? lastOrderAt;

  factory PanelCustomer.fromJson(Map<String, dynamic> json) => PanelCustomer(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        reservationCount: (json['reservationCount'] as num?)?.toInt() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
        email: json['email'] as String?,
        lastOrderAt: json['lastOrderAt'] as String?,
      );
}

class PanelCustomerDetail {
  const PanelCustomerDetail(
      {required this.profile,
      required this.orders,
      required this.reservations});

  final PanelCustomer profile;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> reservations;

  factory PanelCustomerDetail.fromJson(Map<String, dynamic> json) =>
      PanelCustomerDetail(
        profile: PanelCustomer.fromJson(
            Map<String, dynamic>.from(json['profile'] as Map)),
        orders: (json['orders'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [],
        reservations: (json['reservations'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [],
      );
}
