import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

Map<String, dynamic> _json({
  String id = '6a9e23a52204c50612306408',
  String role = 'owner',
  List<String> permissions = const ['full_access'],
}) =>
    {
      'restaurantId': id,
      'name': 'برغر لاب',
      'nameEn': 'Burger Lab',
      'nameAr': 'برغر لاب',
      'role': role,
      'permissions': permissions,
      'status': 'active',
    };

void main() {
  test('parses the full verify-otp restaurant entry', () {
    final r = StaffRestaurant.fromJson(_json());

    expect(r.restaurantId, '6a9e23a52204c50612306408');
    expect(r.nameEn, 'Burger Lab');
    expect(r.nameAr, 'برغر لاب');
    expect(r.role, 'owner');
    expect(r.permissions, ['full_access']);
    expect(r.status, 'active');
    expect(r.isManager, isTrue);
  });

  test('staff role is not a manager', () {
    final r = StaffRestaurant.fromJson(_json(role: 'staff'));

    expect(r.role, 'staff');
    expect(r.isManager, isFalse);
  });

  test('missing fields degrade to empty values instead of throwing', () {
    final r = StaffRestaurant.fromJson(const {});

    expect(r.restaurantId, '');
    expect(r.role, '');
    expect(r.permissions, isEmpty);
    expect(r.displayName('en'), '');
  });

  test('displayName prefers the requested locale with fallback', () {
    final r = StaffRestaurant.fromJson(_json());

    expect(r.displayName('en'), 'Burger Lab');
    expect(r.displayName('ar'), 'برغر لاب');
  });

  test('round-trips through toJson for cache persistence', () {
    final r = StaffRestaurant.fromJson(_json());

    final restored = StaffRestaurant.fromJson(r.toJson());

    expect(restored.restaurantId, r.restaurantId);
    expect(restored.nameEn, r.nameEn);
    expect(restored.role, r.role);
    expect(restored.permissions, r.permissions);
  });

  test('canManage: owner and manager and full_access only', () {
    expect(StaffRestaurant.fromJson(_json()).canManage, isTrue);            // owner
    expect(StaffRestaurant.fromJson(_json(role: 'manager')).canManage, isTrue);
    expect(StaffRestaurant.fromJson(_json(role: 'staff', permissions: [])).canManage, isFalse);
    expect(
      StaffRestaurant.fromJson(
              _json(role: 'staff')..['permissions'] = ['full_access'])
          .canManage,
      isTrue,
    );
  });
}
