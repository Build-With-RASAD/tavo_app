// lib/feature/panel_branches/data/model/branch_models.dart
class PanelBranch {
  const PanelBranch({
    required this.id,
    required this.arName,
    required this.enName,
    required this.address,
    required this.city,
    required this.region,
    required this.phones,
    required this.workingHours,
    this.email,
    this.whatsapp,
    this.latitude,
    this.longitude,
    this.managerName,
    this.displayOrder = 0,
    this.isActive = true,
    this.isMain = false,
  });

  final String id;
  final String arName;
  final String enName;
  final String address;
  final String city;
  final String region;
  final List<String> phones;
  final Map<String, Map<String, dynamic>> workingHours;
  final String? email;
  final String? whatsapp;
  final double? latitude;
  final double? longitude;
  final String? managerName;
  final int displayOrder;
  final bool isActive;
  final bool isMain; // the model field — never `isPrimary`

  static String _localized(Map<String, dynamic> json, String field) {
    final ar = json['ar'];
    final en = json['en'];
    if (ar is Map && ar[field] is String && (ar[field] as String).isNotEmpty) {
      return ar[field] as String;
    }
    if (en is Map && en[field] is String) return en[field] as String;
    return '';
  }

  factory PanelBranch.fromJson(Map<String, dynamic> json) {
    final hours = json['workingHours'];
    return PanelBranch(
      id: json['_id'] as String? ?? '',
      arName: (json['ar'] is Map ? json['ar']['name'] : null) as String? ?? '',
      enName: (json['en'] is Map ? json['en']['name'] : null) as String? ?? '',
      address: _localized(json, 'address'),
      city: _localized(json, 'city'),
      region: _localized(json, 'region'),
      phones:
          (json['phones'] as List?)?.map((e) => '$e').toList() ?? const [],
      workingHours: hours is Map
          ? {
              for (final e in hours.entries)
                '${e.key}': e.value is Map
                    ? Map<String, dynamic>.from(e.value as Map)
                    : <String, dynamic>{},
            }
          : const {},
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      managerName:
          json['manager'] is Map ? json['manager']['name'] as String? : null,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isMain: json['isMain'] as bool? ?? false,
    );
  }
}
