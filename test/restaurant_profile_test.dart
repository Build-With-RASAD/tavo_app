// test/restaurant_profile_test.dart
//
// The profile editor must send only what changed: two managers editing
// different fields should never overwrite each other with stale values.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/restaurant_panel/data/model/restaurant_profile.dart';

const _base = RestaurantProfile(
  nameAr: 'تافو',
  nameEn: 'Tavo',
  descriptionAr: 'وصف',
  descriptionEn: 'Description',
  addressAr: 'الرياض',
  addressEn: 'Riyadh',
  phone: '+966500000000',
  email: 'old@tavo.sa',
  instagram: '@old',
  logoUrl: '/uploads/logo.png',
);

void main() {
  test('parses the panel profile shape', () {
    final profile = RestaurantProfile.fromJson({
      'name': {'ar': 'تافو', 'en': 'Tavo'},
      'description': {'ar': 'وصف', 'en': 'Description'},
      'address': {'ar': 'الرياض', 'en': 'Riyadh'},
      'phone': '+966500000000',
      'contact': {
        'email': 'a@b.sa',
        'whatsapp': '',
        'socialLinks': {'instagram': '@tavo'},
      },
      'logoUrl': '/uploads/logo.png',
      'coverUrl': '/uploads/cover.png',
      'ratingsAverage': 4.6,
      'ratingsQuantity': 120,
    });

    expect(profile.nameEn, 'Tavo');
    expect(profile.addressEn, 'Riyadh');
    expect(profile.email, 'a@b.sa');
    expect(profile.instagram, '@tavo');
    expect(profile.coverUrl, '/uploads/cover.png');
    expect(profile.hasRating, isTrue);
    expect(profile.ratingsAverage, 4.6);
  });

  test('diffFrom sends only the changed field', () {
    final draft = _base.copyWith(nameEn: 'Tavo House');

    expect(draft.diffFrom(_base), {
      'en': {'name': 'Tavo House'},
    });
  });

  test('diffFrom groups both languages and contact changes', () {
    final draft = _base.copyWith(
      nameAr: 'تافو هاوس',
      descriptionEn: 'New description',
      phone: '+966511111111',
      email: 'new@tavo.sa',
      instagram: '@new',
    );

    final body = draft.diffFrom(_base);

    expect(body['ar'], {'name': 'تافو هاوس'});
    expect(body['en'], {'description': 'New description'});
    expect(body['phone'], '+966511111111');
    expect(body['contact'], {
      'email': 'new@tavo.sa',
      'socialLinks': {'instagram': '@new'},
    });
  });

  test('an untouched draft produces an empty body', () {
    expect(_base.diffFrom(_base), isEmpty);
  });

  test('whitespace-only edits are not sent', () {
    final draft = _base.copyWith(nameEn: '   ');

    expect(draft.diffFrom(_base), isEmpty);
  });
}
