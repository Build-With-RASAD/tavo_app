// test/panel_schedule_test.dart
//
// Pure scheduling/queue logic behind the reservations, waitlist and orders
// screens. No widgets: these rules decide what staff sees first, so they are
// tested directly.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/booking/data/model/reservation_schedule.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

BookingModel _booking(
  String id,
  DateTime start, {
  String status = 'confirmed',
  int guests = 2,
}) =>
    BookingModel(
      id: id,
      startAt: start,
      endAt: start.add(const Duration(hours: 2)),
      guestsCount: guests,
      status: status,
      createdAt: start.toIso8601String(),
    );

PanelWaitlistEntry _wait(String id, DateTime created, {String status = 'waiting'}) =>
    PanelWaitlistEntry(
      id: id,
      ticketCode: id,
      guestsCount: 2,
      customerName: 'Guest $id',
      customerPhone: '+966500000000',
      status: status,
      createdAt: created.toIso8601String(),
    );

void main() {
  group('groupReservationsByDay', () {
    test('groups by local day, days ascending, rows by start time', () {
      final days = groupReservationsByDay([
        _booking('c', DateTime(2026, 10, 25, 20)),
        _booking('a', DateTime(2026, 10, 24, 19)),
        _booking('b', DateTime(2026, 10, 24, 13, 30)),
      ]);

      expect(days, hasLength(2));
      expect(days.first.date, DateTime(2026, 10, 24));
      expect(days.first.bookings.map((b) => b.id), ['b', 'a']);
      expect(days.last.bookings.single.id, 'c');
    });

    test('sums covers per day', () {
      final days = groupReservationsByDay([
        _booking('a', DateTime(2026, 10, 24, 19), guests: 4),
        _booking('b', DateTime(2026, 10, 24, 21), guests: 3),
      ]);

      expect(days.single.guests, 7);
    });
  });

  group('reservationDayLabel', () {
    final now = DateTime(2026, 10, 24, 12);

    test('names today and tomorrow in the requested language', () {
      expect(
        reservationDayLabel(
          DateTime(2026, 10, 24),
          now,
          'en',
          today: 'Today',
          tomorrow: 'Tomorrow',
        ),
        'Today',
      );
      expect(
        reservationDayLabel(
          DateTime(2026, 10, 25),
          now,
          'ar',
          today: 'اليوم',
          tomorrow: 'غدًا',
        ),
        'غدًا',
      );
    });

    test('falls back to a short date with the right month name', () {
      expect(
        reservationDayLabel(
          DateTime(2026, 11, 3),
          now,
          'en',
          today: 'Today',
          tomorrow: 'Tomorrow',
        ),
        '3 Nov',
      );
      expect(
        reservationDayLabel(
          DateTime(2026, 11, 3),
          now,
          'ar',
          today: 'اليوم',
          tomorrow: 'غدًا',
        ),
        '3 نوفمبر',
      );
    });
  });

  group('timeline', () {
    test('counts reservations per hour', () {
      final counts = reservationsPerHour([
        _booking('a', DateTime(2026, 10, 24, 19)),
        _booking('b', DateTime(2026, 10, 24, 19, 45)),
        _booking('c', DateTime(2026, 10, 24, 21)),
      ]);

      expect(counts[19], 2);
      expect(counts[21], 1);
      expect(counts.containsKey(20), isFalse);
    });

    test('draws the whole shift and widens for early or late bookings', () {
      expect(timelineHours([]).first, 10);
      expect(timelineHours([]).last, 23);
      expect(timelineHours([_booking('early', DateTime(2026, 10, 24, 8))]).first,
          8);
      // 01:00 is before the shift, so the window starts there and still runs
      // to the end of the evening.
      final overnight =
          timelineHours([_booking('late', DateTime(2026, 10, 25, 1))]);
      expect(overnight.first, 1);
      expect(overnight.last, 23);
    });

    test('arrivals needing attention keep only imminent or late bookings', () {
      final now = DateTime(2026, 10, 24, 19);
      final rows = arrivalsNeedingAttention([
        _booking('late', DateTime(2026, 10, 24, 18, 45)),
        _booking('soon', DateTime(2026, 10, 24, 19, 20)),
        _booking('later', DateTime(2026, 10, 24, 21)),
        _booking('seated', DateTime(2026, 10, 24, 19, 5), status: 'seated'),
        _booking('done', DateTime(2026, 10, 24, 18), status: 'completed'),
      ], now);

      expect(rows.map((b) => b.id), ['late', 'soon']);
    });
  });

  group('waitlistQueuePositions', () {
    test('ranks only the live line, oldest first', () {
      final positions = waitlistQueuePositions([
        _wait('new', DateTime(2026, 10, 24, 13)),
        _wait('old', DateTime(2026, 10, 24, 12)),
        _wait('seated', DateTime(2026, 10, 24, 11), status: 'confirmed'),
        _wait('notified', DateTime(2026, 10, 24, 12, 30), status: 'notified'),
      ]);

      expect(positions['old'], 1);
      expect(positions['notified'], 2);
      expect(positions['new'], 3);
      expect(positions.containsKey('seated'), isFalse);
    });
  });

  group('PanelOrder.fromJson', () {
    test('reads the table, party size, seats and guest notes', () {
      final order = PanelOrder.fromJson({
        '_id': 'o1',
        'orderNumber': 'ORD-1',
        'menuItems': [
          {'name': 'Mandi', 'quantity': 2, 'unitPrice': 60, 'lineTotal': 120},
        ],
        'totalPrice': 130,
        'paymentStatus': 'unpaid',
        'orderStatus': 'preparing',
        'createdAt': '2026-10-24T19:00:00.000Z',
        'source': 'qr_table',
        'tableId': {'code': 'T1-1', 'zone': 'Terrace', 'seats': 4},
        'sessionId': {
          'code': 'K7Q2',
          'guests': [
            {'_id': 'g1'},
            {'_id': 'g2'},
          ],
        },
        'notes': '  no onions  ',
      });

      expect(order.tableCode, 'T1-1');
      expect(order.zone, 'Terrace');
      expect(order.tableSeats, 4);
      expect(order.guestCount, 2);
      expect(order.sessionCode, 'K7Q2');
      expect(order.notes, 'no onions');
      expect(order.isTableOrder, isTrue);
      expect(orderSourceLabelKey(order.source), 'source_qr_table');
    });

    test('falls back to the reservation party size and tolerates gaps', () {
      final order = PanelOrder.fromJson({
        '_id': 'o2',
        'totalPrice': 40,
        'reservationId': {'guestsCount': 6},
      });

      expect(order.guestCount, 6);
      expect(order.notes, '');
      expect(order.tableSeats, 0);
      expect(order.isTableOrder, isFalse);
      expect(orderSourceLabelKey(''), '');
    });

    test('formats elapsed minutes for the row timer', () {
      expect(formatElapsed(0), '0m');
      expect(formatElapsed(12), '12m');
      expect(formatElapsed(75), '1h 15m');
    });
  });
}
