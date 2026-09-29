import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';

Map<String, dynamic> _base() => {
      '_id': 'res1',
      'startAt': '2026-10-01T19:30:00.000',
      'endAt': '2026-10-01T21:30:00.000',
      'createdAt': '2026-09-29',
      'status': 'pending',
      'guestsCount': 2,
    };

void main() {
  test('parses the guest from the populated userId', () {
    final booking = BookingModel.fromJson(
      _base()
        ..['userId'] = {
          '_id': 'u1',
          'name': 'Layla Haddad',
          'phone': '+966500000001',
        },
    );

    expect(booking.guestName, 'Layla Haddad');
    expect(booking.guestPhone, '+966500000001');
  });

  test('falls back to the embedded guest customer', () {
    final booking = BookingModel.fromJson(
      _base()
        ..['customer'] = {
          'name': 'Walk-in Guest',
          'phone': '+966511111111',
        },
    );

    expect(booking.guestName, 'Walk-in Guest');
    expect(booking.guestPhone, '+966511111111');
  });

  test('defaults to empty guest for customer own-booking payloads', () {
    final booking = BookingModel.fromJson(_base());

    expect(booking.guestName, '');
    expect(booking.guestPhone, '');
  });
}
