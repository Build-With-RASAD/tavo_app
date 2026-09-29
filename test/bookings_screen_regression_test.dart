import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/booking/data/repo/bookings_repo.dart';
import 'package:tavo/feature/booking/ui/logic/bookings_cubit.dart';
import 'package:tavo/feature/booking/ui/screens/bookings_screen.dart';
import 'package:tavo/feature/booking/ui/widgets/booking_card.dart';
import 'package:tavo/feature/booking/ui/widgets/booking_details_sheet.dart';
import 'package:tavo/feature/booking/ui/widgets/order_details_loading_sheet.dart';

import 'helpers/app_shell.dart';

/// Regression tests for two critical bugs in [BookingsScreen]:
///
/// 1. `b.id.substring(0, 8)` throws `RangeError` while building a booking
///    whose id is empty or shorter than 8 characters.
/// 2. The details `BlocConsumer` listener popped the navigator
///    unconditionally: if the loading sheet had already been dismissed
///    by the user when the response arrived, the pop removed the *screen
///    itself* instead of the (already gone) sheet.
///
/// The details "request" resolves after 5s of the fake test clock
/// (`Future.delayed`), so tests control exactly when the response lands.
BookingModel _booking({String id = ''}) => BookingModel(
      id: id,
      startAt: DateTime(2026, 10, 1, 19, 30),
      endAt: DateTime(2026, 10, 1, 21, 30),
      createdAt: '2026-09-29',
      restaurantNameEn: 'Testaurant',
      restaurantNameAr: 'مطعم تجريبي',
      status: 'pending',
    );

const _requestLatency = Duration(seconds: 5);

class FakeBookingsCubit extends BookingsCubit {
  FakeBookingsCubit() : super(BookingsRepo(ApiService()));

  /// When set, the details request "succeeds" with this booking.
  BookingModel? nextSelected;

  static const nextError = 'network down';

  @override
  Future<void> loadBookings() async {
    if (isClosed) return;
    emit(state.copyWith(loading: false, error: null, bookings: [_booking()]));
  }

  @override
  Future<void> loadBookingDetails(String reservationId) async {
    if (isClosed) return;
    emit(state.copyWith(
      loadingDetails: true,
      detailsError: null,
      selectedBooking: null,
      orderDetails: null,
    ));
    await Future<void>.delayed(_requestLatency);
    if (isClosed) return;
    if (nextSelected != null) {
      emit(state.copyWith(loadingDetails: false, selectedBooking: nextSelected));
    } else {
      emit(state.copyWith(loadingDetails: false, detailsError: nextError));
    }
  }

  @override
  void clearDetails() {
    if (isClosed) return;
    emit(state.copyWith(
      selectedBooking: null,
      orderDetails: null,
      detailsError: null,
    ));
  }
}

late FakeBookingsCubit fake;

/// Pushes [BookingsScreen] onto a placeholder home screen and returns the
/// navigator context for later assertions.
Future<BuildContext> _pushBookingsScreen(WidgetTester tester) async {
  BuildContext? navCtx;
  await tester.pumpWidget(appShell(Builder(builder: (context) {
    navCtx = context;
    return const Text('home-placeholder');
  })));
  await pumpUntil(tester, () => navCtx != null);
  expect(navCtx, isNotNull, reason: 'the shell home never built');

  Navigator.of(navCtx!).push(
    MaterialPageRoute<void>(builder: (_) => const BookingsScreen()),
  );
  await tester.pumpAndSettle();
  expect(find.byType(BookingsScreen), findsOneWidget);
  return navCtx!;
}

/// Taps "View Details" on the single seeded booking and lets the modal
/// loading sheet's entrance animation finish (bounded pumps only — the
/// sheet contains an indeterminate spinner, so pumpAndSettle would hang).
Future<void> _openDetailsLoadingSheet(WidgetTester tester) async {
  await tester.tap(find.text('View Details'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(OrderDetailsLoadingSheet), findsOneWidget);
}

/// Dismisses a modal bottom sheet via its barrier (top of the screen).
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 80));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Runs the 4s SnackBar timer to completion so no timers leak at teardown.
Future<void> _drainSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnv);

  setUp(() async {
    if (getIt.isRegistered<BookingsCubit>()) {
      await getIt.unregister<BookingsCubit>();
    }
    fake = FakeBookingsCubit();
    getIt.registerSingleton<BookingsCubit>(fake);
  });

  testWidgets(
      'renders a reservation with an empty id without throwing '
      '(substring(0, 8) regression)', (tester) async {
    await tester.pumpWidget(appShell(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'building a booking card must not throw RangeError for '
            'ids shorter than 8 characters');
    expect(find.byType(BookingCard), findsOneWidget);
  });

  testWidgets(
      'details response after the loading sheet was dismissed must not pop '
      'the bookings screen (unconditional-pop regression)', (tester) async {
    await _pushBookingsScreen(tester);
    await _openDetailsLoadingSheet(tester);

    // The user dismisses the loading sheet while the request is in flight.
    await _dismissSheet(tester);
    expect(find.byType(OrderDetailsLoadingSheet), findsNothing);

    // The response now arrives with an error (request latency elapses).
    await tester.pump(_requestLatency);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BookingsScreen), findsOneWidget,
        reason: 'with no loading sheet open the listener must not pop, '
            'otherwise it removes the screen itself');
    expect(find.text(FakeBookingsCubit.nextError), findsOneWidget,
        reason: 'the failure must still surface as a SnackBar');

    await _drainSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'details failure while the loading sheet is open dismisses only the '
      'sheet, not the screen', (tester) async {
    await _pushBookingsScreen(tester);
    await _openDetailsLoadingSheet(tester);

    await tester.pump(_requestLatency);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OrderDetailsLoadingSheet), findsNothing);
    expect(find.byType(BookingsScreen), findsOneWidget);
    expect(find.text(FakeBookingsCubit.nextError), findsOneWidget);

    await _drainSnackBar(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('details success swaps the loading sheet for the details sheet',
      (tester) async {
    fake.nextSelected = _booking();
    await _pushBookingsScreen(tester);
    await _openDetailsLoadingSheet(tester);

    await tester.pump(_requestLatency);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(OrderDetailsLoadingSheet), findsNothing);
    expect(find.byType(BookingDetailsSheet), findsOneWidget);
    expect(find.byType(BookingsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
