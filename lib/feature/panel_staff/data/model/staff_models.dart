// lib/feature/panel_staff/data/model/staff_models.dart
/// The 14-value permission enum, backend order (staff-assignment.model.js).
const kPanelPermissions = <String>[
  'view_orders', 'manage_orders',
  'view_reservations', 'manage_reservations',
  'view_menu', 'manage_menu',
  'view_tables', 'manage_tables',
  'view_reviews', 'manage_reviews',
  'view_reports', 'manage_settings',
  'manage_staff', 'full_access',
];

class PanelStaffMember {
  const PanelStaffMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.permissions,
    required this.status,
    this.email,
  });

  final String id; // StaffAssignment _id
  final String userId;
  final String name;
  final String phone;
  final String role;
  final List<String> permissions;
  final String status;
  final String? email;

  factory PanelStaffMember.fromJson(Map<String, dynamic> json) {
    final user = json['userId'];
    return PanelStaffMember(
      id: json['_id'] as String? ?? '',
      userId: user is Map ? user['_id'] as String? ?? '' : '$user',
      name: user is Map ? user['name'] as String? ?? '' : '',
      phone: user is Map ? user['phone'] as String? ?? '' : '',
      email: user is Map ? user['email'] as String? : null,
      role: json['role'] as String? ?? 'staff',
      permissions:
          (json['permissions'] as List?)?.map((e) => '$e').toList() ?? const [],
      status: json['status'] as String? ?? 'active',
    );
  }
}
