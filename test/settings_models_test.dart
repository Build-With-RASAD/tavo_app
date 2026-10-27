// test/settings_models_test.dart
//
// The wire contract for booking rules.
//
// Regression guard: the settings screen used to PUT a four-key
// `reservationSettings` object, and `PUT /settings` REPLACES that object
// wholesale — so saving the form silently reset six fields to their schema
// defaults. These tests pin the full ten-key payload and the five-key
// celebration payload.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/panel_settings/data/model/settings_models.dart';

void main() {
  const strings = {
    'slotDurationMinutes': 90,
    'maxDaysInAdvance': 30,
    'bufferTimeMinutes': 20,
    'minPartySize': 2,
    'maxPartySize': 12,
    'requireDeposit': true,
    'depositAmount': 50,
    'depositPartyThreshold': 6,
    'allowWaitlist': false,
    'cancellationWindowMinutes': 240,
  };

  const celebration = <String, dynamic>{
    'offersBirthdayPackage': true,
    'offersAnniversaryPackage': true,
    'specialMenuAvailable': true,
    'needsAdvanceNotice': false,
    'minAdvanceNoticeDays': 7,
  };

  test('reservation settings parse every field the API returns', () {
    final rs = ReservationSettings.fromJson(strings);

    expect(rs.slotDurationMinutes, 90);
    expect(rs.maxDaysInAdvance, 30);
    expect(rs.bufferTimeMinutes, 20);
    expect(rs.minPartySize, 2);
    expect(rs.maxPartySize, 12);
    expect(rs.requireDeposit, isTrue);
    expect(rs.depositAmount, 50);
    expect(rs.depositPartyThreshold, 6);
    expect(rs.allowWaitlist, isFalse);
    expect(rs.cancellationWindowMinutes, 240);
  });

  test('celebration features fold into the same value', () {
    final rs = ReservationSettings.fromJson(strings).withCelebration(celebration);

    expect(rs.offersBirthdayPackage, isTrue);
    expect(rs.offersAnniversaryPackage, isTrue);
    expect(rs.specialMenuAvailable, isTrue);
    expect(rs.needsAdvanceNotice, isFalse);
    expect(rs.minAdvanceNoticeDays, 7);
    expect(rs.hasOccasionPackages, isTrue);
  });

  test('a missing celebration block keeps the current values', () {
    final rs = ReservationSettings.fromJson(strings).withCelebration(null);

    expect(rs.offersBirthdayPackage, isFalse);
    expect(rs.needsAdvanceNotice, isTrue);
    expect(rs.minAdvanceNoticeDays, 3);
  });

  test('the reservation payload carries all ten keys', () {
    final json = ReservationSettings.fromJson(strings).toReservationJson();

    expect(json.keys.toSet(), <String>{
      'slotDurationMinutes',
      'maxDaysInAdvance',
      'bufferTimeMinutes',
      'minPartySize',
      'maxPartySize',
      'requireDeposit',
      'depositAmount',
      'depositPartyThreshold',
      'allowWaitlist',
      'cancellationWindowMinutes',
    });
  });

  test('the celebration payload carries all five keys', () {
    final json = ReservationSettings.fromJson(strings).toCelebrationJson();

    expect(json.keys.toSet(), <String>{
      'offersBirthdayPackage',
      'offersAnniversaryPackage',
      'specialMenuAvailable',
      'needsAdvanceNotice',
      'minAdvanceNoticeDays',
    });
  });

  test('a round trip through both halves is lossless', () {
    final original =
        ReservationSettings.fromJson(strings).withCelebration(celebration);

    final restored = ReservationSettings.fromJson(original.toReservationJson())
        .withCelebration(original.toCelebrationJson());

    expect(restored, original);
  });

  group('working-day windows', () {
    test('a normal window is its length', () {
      const day = WorkingDayEntry(
          day: 'sunday', openTime: '09:00', closeTime: '23:00');
      expect(day.openMinutes, 14 * 60);
    });

    test('a window that crosses midnight wraps instead of going negative', () {
      const day = WorkingDayEntry(
          day: 'friday', openTime: '22:00', closeTime: '02:00');
      expect(day.openMinutes, 4 * 60);
    });

    test('a closed day has no window and malformed text is unknown', () {
      expect(
        const WorkingDayEntry(day: 'monday', isClosed: true).openMinutes,
        0,
      );
      expect(
        const WorkingDayEntry(day: 'monday', openTime: '9:00').openMinutes,
        isNull,
      );
      expect(WorkingDayEntry.minutesOf('99:99'), isNull);
    });
  });
}
