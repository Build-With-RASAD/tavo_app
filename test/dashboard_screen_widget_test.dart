// test/dashboard_screen_widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/dashboard_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/dashboard_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';

import 'helpers/app_shell.dart';

class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());
  Object? error;
  int calls = 0;
  String? lastRestaurantId;

  @override
  Future<DashboardStats> getDashboard(String restaurantId) async {
    calls++;
    lastRestaurantId = restaurantId;
    if (error != null) throw error!;
    return DashboardStats.fromJson(const {
      'orders': {'total': 12, 'pending': 3, 'newOrders': 2, 'avgOrderValue': 55.2},
      'reservations': {'total': 8},
      'revenue': {'total': 1234, 'thisMonth': 400},
      'reviews': {
        'averageRating': 4.6,
        'recent': [
          {'_id': 'r1', 'rating': 5, 'comment': 'Great', 'createdAt': 'x',
           'user': {'name': 'سعد السبيعي'}},
        ],
      },
    });
  }
}

const _venue = StaffRestaurant(
  restaurantId: 'r1', nameEn: 'Burger Lab', nameAr: 'برغر لاب', role: 'owner',
);

/// Extras repo with empty data: these tests only care about the headline
/// stats — the extras section renders loaded-but-empty with no network.
class _EmptyExtrasRepo extends DashboardPanelRepo {
  _EmptyExtrasRepo() : super(api: ApiService());

  @override
  Future<List<PanelPhysicalTable>> getFloorTables(String restaurantId) async =>
      [];

  @override
  Future<({List<PanelWaitlistEntry> entries, int total})> getWaitlistPreview(
          String restaurantId) async =>
      (entries: <PanelWaitlistEntry>[], total: 0);

  @override
  Future<List<DashboardOpenOrder>> getOpenOrders(String restaurantId) async =>
      [];
}

void main() {
  setUpAll(initTestEnv);
  late FakePanelRepo repo;
  final getIt = GetIt.instance;

  setUp(() {
    repo = FakePanelRepo();
    getIt.registerFactory<RestaurantPanelRepo>(() => repo);
    getIt.registerFactory<DashboardCubit>(() => DashboardCubit(repo));
    // Wave E2 wiring: the screen now builds the extras section too — seed an
    // empty extras repo BEFORE registerDashboardModule so its guarded repo
    // registration is skipped and only the cubit factory is claimed.
    getIt.registerLazySingleton<DashboardPanelRepo>(() => _EmptyExtrasRepo());
    registerDashboardModule();
  });
  tearDown(getIt.reset);

  testWidgets('shows stats and recent reviews for the loaded venue',
      (tester) async {
    await tester.pumpWidget(
        appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.lastRestaurantId, 'r1');
    expect(find.text('12'), findsWidgets);          // total orders value
    expect(find.text('سعد السبيعي'), findsOneWidget); // recent review author
    expect(find.text('4.6'), findsOneWidget);        // avg rating
  });

  testWidgets('error state shows retry and recovers on tap', (tester) async {
    repo.error = 'No internet connection';

    await tester.pumpWidget(
        appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('سعد السبيعي'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('renders ListSkeleton while loading', (tester) async {
    // repo that never resolves its first call; reset first so the setUp
    // registrations don't collide (controller ruling: T9 test scaffolding).
    await getIt.reset();
    final pending = FakePanelRepo();
    getIt
      ..registerFactory<RestaurantPanelRepo>(() => pending)
      ..registerFactory<DashboardCubit>(() => DashboardCubit(pending))
      ..registerLazySingleton<DashboardPanelRepo>(() => _EmptyExtrasRepo());
    registerDashboardModule();
    await tester.pumpWidget(
        appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)));
    await tester.pump(); // first frame: loading
    expect(find.byType(ListSkeleton), findsOneWidget);
  });
}
