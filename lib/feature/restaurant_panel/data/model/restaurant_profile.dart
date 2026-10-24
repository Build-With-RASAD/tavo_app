// lib/feature/restaurant_panel/data/model/restaurant_profile.dart
//
// The venue's own profile, as the owner edits it. Every field defaults to an
// empty string so a partially filled restaurant still renders a usable form.
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _text(Object? value) => value == null ? '' : value.toString();

double _num(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

class RestaurantProfile {
  const RestaurantProfile({
    this.nameAr = '',
    this.nameEn = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.addressAr = '',
    this.addressEn = '',
    this.phone = '',
    this.email = '',
    this.whatsapp = '',
    this.instagram = '',
    this.tiktok = '',
    this.logoUrl = '',
    this.coverUrl = '',
    this.ratingsAverage = 0,
    this.ratingsQuantity = 0,
  });

  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String addressAr;
  final String addressEn;
  final String phone;
  final String email;
  final String whatsapp;
  final String instagram;
  final String tiktok;
  final String logoUrl;
  final String coverUrl;
  final double ratingsAverage;
  final int ratingsQuantity;

  bool get hasRating => ratingsQuantity > 0;

  factory RestaurantProfile.fromJson(Map<String, dynamic> json) {
    final name = _map(json['name']);
    final description = _map(json['description']);
    final address = _map(json['address']);
    final contact = _map(json['contact']);
    final social = _map(contact['socialLinks']);

    return RestaurantProfile(
      nameAr: _text(name['ar']),
      nameEn: _text(name['en']),
      descriptionAr: _text(description['ar']),
      descriptionEn: _text(description['en']),
      addressAr: _text(address['ar']),
      addressEn: _text(address['en']),
      phone: _text(json['phone']),
      email: _text(contact['email']),
      whatsapp: _text(contact['whatsapp']),
      instagram: _text(social['instagram']),
      tiktok: _text(social['tiktok']),
      logoUrl: _text(json['logoUrl']),
      coverUrl: _text(json['coverUrl']),
      ratingsAverage: _num(json['ratingsAverage']),
      ratingsQuantity: _num(json['ratingsQuantity']).toInt(),
    );
  }

  RestaurantProfile copyWith({
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    String? addressAr,
    String? addressEn,
    String? phone,
    String? email,
    String? whatsapp,
    String? instagram,
    String? tiktok,
    String? logoUrl,
    String? coverUrl,
  }) => RestaurantProfile(
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    addressAr: addressAr ?? this.addressAr,
    addressEn: addressEn ?? this.addressEn,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    whatsapp: whatsapp ?? this.whatsapp,
    instagram: instagram ?? this.instagram,
    tiktok: tiktok ?? this.tiktok,
    logoUrl: logoUrl ?? this.logoUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    ratingsAverage: ratingsAverage,
    ratingsQuantity: ratingsQuantity,
  );

  /// Only the changed fields, so two owners editing different tabs never
  /// overwrite each other with stale values.
  Map<String, dynamic> diffFrom(RestaurantProfile base) {
    final body = <String, dynamic>{};
    void put(Map<String, dynamic> target, String key, String value) {
      if (value.trim().isEmpty) return;
      target[key] = value.trim();
    }

    final ar = <String, dynamic>{};
    if (nameAr.trim() != base.nameAr.trim()) put(ar, 'name', nameAr);
    if (descriptionAr.trim() != base.descriptionAr.trim()) {
      put(ar, 'description', descriptionAr);
    }
    if (addressAr.trim() != base.addressAr.trim()) put(ar, 'address', addressAr);

    final en = <String, dynamic>{};
    if (nameEn.trim() != base.nameEn.trim()) put(en, 'name', nameEn);
    if (descriptionEn.trim() != base.descriptionEn.trim()) {
      put(en, 'description', descriptionEn);
    }
    if (addressEn.trim() != base.addressEn.trim()) put(en, 'address', addressEn);

    if (ar.isNotEmpty) body['ar'] = ar;
    if (en.isNotEmpty) body['en'] = en;
    if (phone.trim() != base.phone.trim()) put(body, 'phone', phone);

    final contact = <String, dynamic>{};
    if (email.trim() != base.email.trim()) put(contact, 'email', email);
    if (whatsapp.trim() != base.whatsapp.trim()) {
      put(contact, 'whatsapp', whatsapp);
    }
    final social = <String, dynamic>{};
    if (instagram.trim() != base.instagram.trim()) {
      put(social, 'instagram', instagram);
    }
    if (tiktok.trim() != base.tiktok.trim()) put(social, 'tiktok', tiktok);
    if (social.isNotEmpty) contact['socialLinks'] = social;
    if (contact.isNotEmpty) body['contact'] = contact;

    return body;
  }
}
