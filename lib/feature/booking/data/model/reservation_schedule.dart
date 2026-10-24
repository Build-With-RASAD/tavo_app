// lib/feature/booking/data/model/reservation_schedule.dart
//
// Pure scheduling helpers for the panel's reservations tab: day grouping,
// Arabic/English clock labels and the per-hour histogram behind "today's
// timeline". Kept out of the widget so the rules can be unit-tested without a
// pumped widget tree.
import 'package:tavo/feature/booking/data/model/booking_model.dart';

/// One calendar day of reservations, already sorted by start time.
class ReservationDay {
  const ReservationDay({required this.date, required this.bookings});

  /// Midnight of the day, in local time.
  final DateTime date;

  /// Reservations that start on [date], earliest first.
  final List<BookingModel> bookings;

  int get guests => bookings.fold(0, (sum, b) => sum + b.guestsCount);
}

/// Midnight of [value] in local time — the grouping key.
DateTime reservationDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Groups [bookings] by start day, returning days ascending and each day's
/// rows sorted by start time. Rows with an unparseable date are dropped by
/// `BookingModel.fromJson` before they reach here, so every row lands in a
/// bucket.
List<ReservationDay> groupReservationsByDay(
  List<BookingModel> bookings,
) {
  final buckets = <DateTime, List<BookingModel>>{};
  for (final booking in bookings) {
    final key = reservationDay(booking.startAt);
    buckets.putIfAbsent(key, () => <BookingModel>[]).add(booking);
  }

  final days = buckets.keys.toList()..sort();
  return [
    for (final day in days)
      ReservationDay(
        date: day,
        bookings: buckets[day]!..sort((a, b) => a.startAt.compareTo(b.startAt)),
      ),
  ];
}

/// `19` → `7 م` (Arabic) / `7 PM` (English). No `intl` locale data needed, so
/// labels are identical in tests and on device.
String hourLabel(int hour, String languageCode) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = languageCode == 'ar'
      ? (hour >= 12 ? 'م' : 'ص')
      : (hour >= 12 ? 'PM' : 'AM');
  return '$h12 $suffix';
}

/// `19:05` → `7:05 م`.
String clockLabel(DateTime value, String languageCode) {
  final h12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = languageCode == 'ar'
      ? (value.hour >= 12 ? 'م' : 'ص')
      : (value.hour >= 12 ? 'PM' : 'AM');
  return '$h12:$minute $suffix';
}

/// Section title for a day: "Today", "Tomorrow", otherwise a short date.
String reservationDayLabel(
  DateTime day,
  DateTime now,
  String languageCode, {
  required String today,
  required String tomorrow,
}) {
  final todayKey = reservationDay(now);
  final target = reservationDay(day);
  final diff = target.difference(todayKey).inDays;

  if (diff == 0) return today;
  if (diff == 1) return tomorrow;

  const monthsAr = [
    '',
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  const monthsEn = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final months = languageCode == 'ar' ? monthsAr : monthsEn;
  return '${target.day} ${months[target.month]}';
}

/// Reservations per hour for one day, keyed by the 24h hour (0–23). Hours with
/// no bookings are absent.
Map<int, int> reservationsPerHour(List<BookingModel> bookings) {
  final counts = <int, int>{};
  for (final booking in bookings) {
    counts.update(booking.startAt.hour, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// The hour window the timeline draws: the full shift 10:00–23:00, widened if
/// a booking falls outside it, so an early breakfast or a late seating is
/// never invisible.
List<int> timelineHours(List<BookingModel> bookings) {
  var first = 10;
  var last = 23;
  for (final booking in bookings) {
    if (booking.startAt.hour < first) first = booking.startAt.hour;
    if (booking.startAt.hour > last) last = booking.startAt.hour;
  }
  return [for (var hour = first; hour <= last; hour++) hour];
}

/// `pending`/`confirmed` bookings that start within [window] minutes, or that
/// already started and are still not seated — the rows staff must act on now.
List<BookingModel> arrivalsNeedingAttention(
  List<BookingModel> bookings,
  DateTime now, {
  Duration window = const Duration(minutes: 30),
}) {
  return bookings.where((booking) {
    if (booking.status != 'pending' && booking.status != 'confirmed') {
      return false;
    }
    final delta = booking.startAt.difference(now);
    return delta.inMinutes <= window.inMinutes;
  }).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
}
