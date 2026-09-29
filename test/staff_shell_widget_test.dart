// test/staff_shell_widget_test.dart
//
// Widget coverage for `StaffShellScreen` (Task 11): the 3-tab staff shell
// that replaced the single-venue `RestaurantHomeScreen`.
//
// Covered per the brief:
//   * defaults to the dashboard tab for the FIRST venue (fake panel repo
//     records `lastRestaurantId == 'r1'`);
//   * the app-bar `switch_restaurant` popup moves the active venue to 'r2',
//     reloads the dashboard and persists through `CacheHelper`;
//   * a tab switch lands on the orders list;
//   * the logout button returns to the staff login screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/staff_shell_screen.dart';
import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/dashboard_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/orders_screen.dart';

import 'helpers/app_shell.dart';

/// Staff auth repo with a recorded, network-free logout.
class FakeStaffRepo extends RestaurantAuthRepo {
  FakeStaffRepo() : super(ApiService());

  List<BookingModel> reservations = const [];
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<List<BookingModel>> getRestaurantReservations(
    String restaurantId,
  ) async {
    return reservations;
  }
}

/// Panel repo recording which venue the dashboard and orders loaded for.
class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());

  int dashboardCalls = 0;
  String? lastRestaurantId;
  List<PanelOrder> orders = const [];

  @override
  Future<DashboardStats> getDashboard(String restaurantId) async {
    dashboardCalls++;
    lastRestaurantId = restaurantId;
    return DashboardStats.fromJson(const {
      'orders': {'total': 12, 'pending': 3, 'newOrders': 2, 'avgOrderValue': 55.2},
      'reservations': {'total': 8},
      'revenue': {'total': 1234, 'thisMonth': 400},
      'reviews': {'averageRating': 4.6, 'recent': <dynamic>[]},
    });
  }

  @override
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return PagedResult(
      items: orders,
      page: 1,
      limit: 20,
      total: orders.length,
      pages: 1,
    );
  }
}

const _venue1 = StaffRestaurant(
  restaurantId: 'r1',
  name: 'برغر لاب',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _venue2 = StaffRestaurant(
  restaurantId: 'r2',
  name: 'بيتزا لاب',
  nameEn: 'Pizza Lab',
  nameAr: 'بيتزا لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _venues = [_venue1, _venue2];

final _booking = BookingModel(
  id: 'b1',
  startAt: DateTime(2026, 10, 1, 19, 30),
  endAt: DateTime(2026, 10, 1, 21, 30),
  createdAt: '2026-09-29',
  restaurantNameEn: 'Burger Lab',
  guestsCount: 4,
  guestName: 'Layla Haddad',
  guestPhone: '+966500000001',
  status: 'pending',
);

final _order = PanelOrder.fromJson(const {
  '_id': '1',
  'orderNumber': 'ORD-2026-011',
  'orderStatus': 'pending',
  'userId': {'name': 'سعد السبيعي', 'phone': '+966515033695'},
  'menuItems': [
    {'name': 'Smoky BBQ Burger', 'quantity': 3, 'unitPrice': 32, 'lineTotal': 96},
  ],
  'subtotal': 96,
  'tax': 14.4,
  'totalPrice': 110.4,
  'paymentStatus': 'paid',
  'createdAt': '2026-09-01T11:52:00.000Z',
});

int _selectedIndex(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Finder _tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  setUpAll(() async {
    await initTestEnv();
    // The shell reads/writes the active venue through CacheHelper; the mock
    // store must exist (initTestEnv installs it) before CacheHelper binds.
    await CacheHelper.init();
  });

  late FakeStaffRepo repo;
  late FakePanelRepo panelRepo;
  final getIt = GetIt.instance;

  setUp(() async {
    // Isolate tests: a venue persisted by a previous test must not become
    // the shell's initial venue ('' is never in the list → first venue wins).
    await CacheHelper.setActiveRestaurant('');

    repo = FakeStaffRepo()..reservations = [_booking];
    panelRepo = FakePanelRepo()..orders = [_order];

    getIt
      ..registerFactory<RestaurantAuthRepo>(() => repo)
      ..registerFactory<RestaurantAuthCubit>(
        () => RestaurantAuthCubit(repo),
      )
      ..registerFactory<RestaurantPanelRepo>(() => panelRepo)
      ..registerFactory<DashboardCubit>(() => DashboardCubit(panelRepo))
      ..registerFactoryParam<OrdersCubit, String, void>(
        (restaurantId, _) => OrdersCubit(panelRepo, restaurantId: restaurantId),
      )
      ..registerFactoryParam<RestaurantHomeCubit, String, void>(
        (restaurantId, _) =>
            RestaurantHomeCubit(repo, restaurantId: restaurantId),
      );
  });

  tearDown(getIt.reset);

  testWidgets('defaults to the dashboard tab for the first venue',
      (tester) async {
    await tester.pumpWidget(appShell(StaffShellScreen(restaurants: _venues)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(StaffShellScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    // The dashboard is the default tab and loaded venue #1.
    expect(_selectedIndex(tester), 0);
    expect(panelRepo.lastRestaurantId, 'r1');
    expect(panelRepo.dashboardCalls, 1);
    // AppBar shows the active venue's display name.
    expect(find.text('Burger Lab'), findsWidgets);
    // The reservations tab is mounted too — IndexedStack keeps every tab
    // alive but hidden tabs count as offstage for finders, so reach them
    // with skipOffstage: false.
    expect(find.text('Layla Haddad', skipOffstage: false), findsOneWidget);
  });

  testWidgets('switching venue from the app bar reloads the dashboard',
      (tester) async {
    await tester.pumpWidget(appShell(StaffShellScreen(restaurants: _venues)));
    await tester.pumpAndSettle();
    expect(panelRepo.dashboardCalls, 1);

    await tester.tap(find.byKey(const ValueKey('switch_restaurant_button')));
    await tester.pumpAndSettle();
    // Popup header carries the `switch_restaurant` i18n key.
    expect(find.text('Switch restaurant'), findsOneWidget);

    await tester.tap(find.text('Pizza Lab'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(panelRepo.lastRestaurantId, 'r2');
    expect(panelRepo.dashboardCalls, 2);
    // The switch persists for the next cold start.
    expect(CacheHelper.getActiveRestaurant(), 'r2');
    // AppBar + dashboard header now show venue #2.
    expect(find.text('Pizza Lab'), findsWidgets);
  });

  testWidgets('switching tabs shows the orders list', (tester) async {
    await tester.pumpWidget(appShell(StaffShellScreen(restaurants: _venues)));
    await tester.pumpAndSettle();

    expect(_selectedIndex(tester), 0);

    await tester.tap(_tab('Orders'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_selectedIndex(tester), 1);
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('ORD-2026-011'), findsOneWidget);
  });

  testWidgets('logout returns to the staff login screen', (tester) async {
    await tester.pumpWidget(appShell(StaffShellScreen(restaurants: _venues)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.logoutCalls, 1);
    expect(find.byType(RestaurantLoginScreen), findsOneWidget);
    expect(find.byType(StaffShellScreen), findsNothing);
  });
}
