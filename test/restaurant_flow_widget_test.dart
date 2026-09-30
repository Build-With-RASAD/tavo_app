import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/auth/ui/data/models/auth_response.dart';
import 'package:tavo/feature/auth/ui/data/models/login_request.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/auth/ui/data/models/verify_otp_request.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/reservations_tab.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_otp_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/staff_shell_screen.dart';
import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/dashboard_screen.dart';

import 'helpers/app_shell.dart';
import 'helpers/dashboard_extras_helper.dart';

/// End-to-end widget coverage for the staff flow:
/// login → OTP → shell → confirm action.
///
/// Task 11: the OTP step now lands on `StaffShellScreen` (dashboard tab by
/// default) and the confirm action is covered through `ReservationsTab`
/// directly; every assertion from the pre-shell flow survives.
class FakeStaffRepo extends RestaurantAuthRepo {
  FakeStaffRepo() : super(ApiService());

  List<StaffRestaurant> venues = const [];
  List<BookingModel> reservations = [];
  int loginCalls = 0;

  @override
  Future<AuthResponse> restaurantLogin(LoginRequest request) async {
    loginCalls++;
    return AuthResponse(
      success: true,
      message: 'OTP sent successfully',
      hasRestaurantAccess: true,
      restaurants: venues,
    );
  }

  @override
  Future<AuthResponse> verifyRestaurantOtp(VerifyOtpRequest request) async {
    if (request.otp != '1111') throw 'Invalid OTP';
    return AuthResponse(
      success: true,
      token: 'tok',
      restaurants: venues,
      isRestaurantOwner: true,
    );
  }

  @override
  Future<List<BookingModel>> getRestaurantReservations(
      String restaurantId) async {
    return reservations;
  }

  @override
  Future<BookingModel> updateReservationStatus({
    required String id,
    required String action,
    String? reason,
  }) async {
    final current = reservations.firstWhere((b) => b.id == id);
    const next = {'confirm': 'confirmed', 'seat': 'seated'};
    final updated = BookingModel(
      id: current.id,
      startAt: current.startAt,
      endAt: current.endAt,
      createdAt: current.createdAt,
      status: next[action] ?? current.status,
      guestsCount: current.guestsCount,
      guestName: current.guestName,
      guestPhone: current.guestPhone,
      restaurantNameEn: current.restaurantNameEn,
    );
    reservations = [
      for (final b in reservations) b.id == id ? updated : b,
    ];
    return updated;
  }
}

/// Benign panel repo for the shell's dashboard/orders tabs: no network, no
/// rows — the flow's assertions live on the reservations side.
class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());

  @override
  Future<DashboardStats> getDashboard(String restaurantId) async {
    return DashboardStats.fromJson(const {
      'orders': {'total': 0, 'pending': 0, 'newOrders': 0, 'avgOrderValue': 0},
      'reservations': {'total': 0},
      'revenue': {'total': 0, 'thisMonth': 0},
      'reviews': {'averageRating': 0, 'recent': <dynamic>[]},
    });
  }

  @override
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return const PagedResult(
      items: <PanelOrder>[],
      page: 1,
      limit: 20,
      total: 0,
      pages: 1,
    );
  }

  List<BookingModel> homeReservations = const [];
  @override
  Future<List<BookingModel>> getReservations(String restaurantId, {int limit = 100}) async => homeReservations;
  @override
  Future<BookingModel> updateReservationAction({required String restaurantId, required String id, required String action, String? reason}) async {
    const next = {'confirm': 'confirmed', 'seat': 'seated', 'complete': 'completed', 'cancel': 'cancelled'};
    final b = homeReservations.firstWhere((e) => e.id == id);
    return BookingModel(
      id: b.id,
      restaurantId: b.restaurantId,
      restaurantNameAr: b.restaurantNameAr,
      restaurantNameEn: b.restaurantNameEn,
      restaurantLogoUrl: b.restaurantLogoUrl,
      restaurantAddress: b.restaurantAddress,
      startAt: b.startAt,
      endAt: b.endAt,
      guestsCount: b.guestsCount,
      status: next[action] ?? action,
      tables: b.tables,
      order: b.order,
      specialRequests: b.specialRequests,
      tablePreference: b.tablePreference,
      createdAt: b.createdAt,
      guestName: b.guestName,
      guestPhone: b.guestPhone,
    );
  }
}

const _venue = StaffRestaurant(
  restaurantId: 'r1',
  name: 'برغر لاب',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

BookingModel _booking({String id = 'b1', String status = 'pending'}) =>
    BookingModel(
      id: id,
      startAt: DateTime(2026, 10, 1, 19, 30),
      endAt: DateTime(2026, 10, 1, 21, 30),
      createdAt: '2026-09-29',
      restaurantNameEn: 'Burger Lab',
      guestsCount: 4,
      guestName: 'Layla Haddad',
      guestPhone: '+966500000001',
      status: status,
    );

void main() {
  setUpAll(initTestEnv);

  late FakeStaffRepo repo;
  late FakePanelRepo panelRepo;
  final getIt = GetIt.instance;

  setUp(() {
    repo = FakeStaffRepo()..venues = [_venue];
    panelRepo = FakePanelRepo();
    getIt.registerFactory<RestaurantAuthCubit>(
      () => RestaurantAuthCubit(repo),
    );
    getIt.registerFactoryParam<RestaurantHomeCubit, String, void>(
      (restaurantId, _) =>
          RestaurantHomeCubit(panelRepo, restaurantId: restaurantId),
    );
    // The OTP step now lands on StaffShellScreen, which builds the
    // dashboard / orders tabs through get_it.
    getIt.registerFactory<RestaurantPanelRepo>(() => panelRepo);
    getIt.registerFactory<DashboardCubit>(() => DashboardCubit(panelRepo));
    getIt.registerFactoryParam<OrdersCubit, String, void>(
      (restaurantId, _) =>
          OrdersCubit(panelRepo, restaurantId: restaurantId),
    );
    // Wave E2: the OTP flow lands on the shell, whose dashboard tab
    // builds the extras section too.
    registerDashboardExtrasForTests();
  });

  tearDown(getIt.reset);

  testWidgets('staff login sends OTP and opens the OTP screen',
      (tester) async {
    await tester.pumpWidget(appShell(const RestaurantLoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '557164151');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Bounded pumps: OtpScreen runs a periodic resend timer, so
    // pumpAndSettle would never settle.
    await pumpUntil(tester, () => find.byType(RestaurantOtpScreen).evaluate().isNotEmpty);

    expect(repo.loginCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(RestaurantOtpScreen), findsOneWidget);
    expect(find.byType(PinCodeTextField), findsOneWidget);
  });

  testWidgets('correct OTP opens the restaurant shell with reservations',
      (tester) async {
    panelRepo.homeReservations = [_booking()];

    final cubit = RestaurantAuthCubit(repo);
    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');
    addTearDown(cubit.close);

    await tester.pumpWidget(
      appShell(
        BlocProvider<RestaurantAuthCubit>.value(
          value: cubit,
          child: const RestaurantOtpScreen(phone: '557164151'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final pinField = find.descendant(
      of: find.byType(PinCodeTextField),
      matching: find.byType(TextField),
    );
    await tester.enterText(pinField, '1111');
    await tester.pump();
    // Bounded pumps: the OTP resend timer keeps frames scheduled, and the
    // navigation transition must be waited out without pumpAndSettle.
    await pumpUntil(
      tester,
      () => find.byType(StaffShellScreen).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 500));
    // IndexedStack keeps every tab mounted; a hidden tab is offstage for
    // finders, so the reservations row is asserted with skipOffstage: false.
    await pumpUntil(
      tester,
      () => find
          .text('Layla Haddad', skipOffstage: false)
          .evaluate()
          .isNotEmpty,
    );

    expect(tester.takeException(), isNull);
    // Task 11: the shell replaces the old single-venue home and opens on
    // its default (dashboard) tab; the guest row lives in the reservations
    // tab, which IndexedStack keeps mounted.
    expect(find.byType(StaffShellScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Layla Haddad', skipOffstage: false), findsOneWidget);
  });

  testWidgets('tapping Confirm flips a pending row to confirmed',
      (tester) async {
    panelRepo.homeReservations = [_booking()];

    await tester.pumpWidget(appShell(const ReservationsTab(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.text('Layla Haddad'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Confirmed'), findsWidgets);
  });
}
