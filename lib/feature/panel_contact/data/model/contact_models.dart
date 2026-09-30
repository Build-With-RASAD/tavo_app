// lib/feature/panel_contact/data/model/contact_models.dart
class PanelContact {
  const PanelContact({
    required this.slug,
    required this.phone,
    required this.email,
    required this.whatsapp,
    required this.socialLinks,
    required this.descriptionAr,
    required this.descriptionEn,
    this.menuUrl,
  });

  final String slug;
  final String? menuUrl; // null when the restaurant has no slug (Task 8)
  final String phone;
  final String email;
  final String whatsapp;
  final Map<String, String> socialLinks;
  final String descriptionAr;
  final String descriptionEn;

  static const socialKeys = <String>[
    'instagram', 'tiktok', 'facebook', 'snapchat', 'x',
  ];

  factory PanelContact.fromJson(Map<String, dynamic> json) {
    final socials = json['socialLinks'];
    final desc = json['description'];
    return PanelContact(
      slug: json['slug'] as String? ?? '',
      menuUrl: json['menuUrl'] as String?,
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      socialLinks: {
        for (final k in socialKeys)
          k: socials is Map ? socials[k] as String? ?? '' : '',
      },
      descriptionAr:
          desc is Map ? desc['ar'] as String? ?? '' : '',
      descriptionEn:
          desc is Map ? desc['en'] as String? ?? '' : '',
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'phone': phone,
        'email': email,
        'whatsapp': whatsapp,
        'socialLinks': socialLinks,
        'description': {'ar': descriptionAr, 'en': descriptionEn},
      };
}
