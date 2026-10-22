// test/dashboard_screen_widget_test.dart
//
// Wave 2 (Task 32): the rebuilt dashboard screen — three zones in one
// scroll view, section-level error isolation and the shell wiring.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/alert_rail.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/live_hero_band.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/occupancy_ring.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/order_pipeline.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/dashboard_screen.dart';

import 'helpers/app_shell.dart';

const _venue = StaffRestaurant(
  restaurantId: 'r1', nameEn: 'Burger Lab', nameAr: 'برغر لاب', role: 'owner',
);

const _payload = {
  'range': {'from': '2026-10-01', 'to': '2026-10-22', 'days': 22},
  'live': {
    'revenueToday': 4820.5,
    'ordersToday': 37,
    'openOrders': 6,
    'ordersByStatus': {'pending': 4, 'preparing': 2},
    'occupiedTables': 9,
    'totalTables': 18,
    'occupancyPct': 50,
    'waitlistCount': 5,
  },
  'kpi': {
    'revenue': {'gross': 96250.75, 'net': 88750.5, 'tax': 7500.25},
    'orders': {'total': 812},
  },
  'trend': {
    'daily': [
      {'date': '2026-10-21', 'revenueGross': 4520.5, 'orders': 38},
      {'date': '2026-10-22', 'revenueGross': 4820.5, 'orders': 37},
    ],
  },
  'topItems': [
    {'name': 'Smoky BBQ Burger', 'quantity': 214, 'revenue': 12412, 'sharePct': 12.9},
  ],
  'alerts': [
    {
      'type': 'high_no_show',
      'severity': 'warning',
      'message': '33.33% of reservations were no-shows',
      'count': 1,
      'action': 'reservations',
    },
  ],
};

/// Analytics repo with a recorded, network-free payload.
class FakeAnalyticsRepo extends AnalyticsPanelRepo {
  FakeAnalyticsRepo() : super(api: ApiService());

  Object? error;
  int calls = 0;
  int liveCalls = 0;
  String? lastRestaurantId;

  @override
  Future<DashboardAnalytics> getAnalytics({
    required String restaurantId,
    required DateTime from,
    required DateTime to,
  }) async {
    calls++;
    lastRestaurantId = restaurantId;
    if (error != null) throw error!;
    return DashboardAnalytics.fromJson(_payload);
  }

  @override
  Future<LiveSnapshot> getLiveSnapshot(String restaurantId) async {
    liveCalls++;
    if (error != null) throw error!;
    return LiveSnapshot.fromJson(
      (_payload['live'] as Map<String, dynamic>));
  }
}

void main() {
  setUpAll(initTestEnv);
  late FakeAnalyticsRepo repo;
  final getIt = GetIt.instance;

  setUp(() {
    repo = FakeAnalyticsRepo();
    getIt.registerLazySingleton<AnalyticsPanelRepo>(() => repo);
    registerDashboardModule();
  });
  tearDown(getIt.reset);

  /// The dashboard is one long scroll view. The surface is set to a realistic
/// phone size (so the ScreenUtil proportions match the design) and the
/// lower zones are reached by scrolling — a lazy list only builds what is
/// on screen.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> scrollDown(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView), Offset(0, -dy));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the three zones with the payload values',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repo.lastRestaurantId, 'r1');
    // The Now zone is on screen from the first frame.
    expect(find.byType(LiveHeroBand), findsOneWidget);
    expect(find.text('4,820.50'), findsOneWidget);

    await scrollDown(tester, 400);
    expect(find.byType(OrderPipeline), findsOneWidget);
    expect(find.byType(OccupancyRing), findsOneWidget);

    await scrollDown(tester, 400);
    expect(find.byType(AlertRail), findsOneWidget);

    await scrollDown(tester, 600);
    expect(find.byType(RevenueTrendChart), findsOneWidget);
  });

  testWidgets('the 20s poll refreshes the live band without blanking the page',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)),
    );
    await tester.pumpAndSettle();
    expect(repo.liveCalls, 1);

    // Let the poll timer fire.
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(repo.liveCalls, 2, reason: 'the poll must run');
    expect(repo.calls, 1, reason: 'the poll must not re-read the heavy endpoint');
    // The page is still there — the poll merged, it did not replace.
    expect(find.byType(ListSkeleton), findsNothing);
    expect(find.byType(LiveHeroBand), findsOneWidget);
    expect(find.text('4,820.50'), findsOneWidget);
  });

  testWidgets('the live band and the quick actions reach the shell',
      (tester) async {
    usePhoneSurface(tester);
    String? orders;
    var newOrder = false;
    var waitlist = false;

    await tester.pumpWidget(
      appShell(
        DashboardScreen(
          restaurantId: 'r1',
          venue: _venue,
          onOpenOrders: (status) => orders = status,
          onNewOrder: () => newOrder = true,
          onOpenWaitlist: () => waitlist = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The open-orders figure opens the Orders tab unfiltered.
    await tester.tap(find.byKey(const ValueKey('dash_live_open_orders')));
    expect(orders, isNull);

    // The waitlist figure opens the waitlist tab.
    await tester.tap(find.byKey(const ValueKey('dash_live_waitlist')));
    expect(waitlist, isTrue);

    // The quick action hands the new-order flow to the shell.
    await tester.tap(find.byKey(const ValueKey('dash_quick_new_order')));
    expect(newOrder, isTrue);
  });

  testWidgets('a failing read renders an inline error, not a blank page',
      (tester) async {
    repo.error = 'No internet connection';

    await tester.pumpWidget(
      appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)),
    );
    await tester.pumpAndSettle();

    // Both reads failed → the page-level error with its retry.
    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
  });

  testWidgets('renders ListSkeleton while loading', (tester) async {
    await tester.pumpWidget(
      appShell(const DashboardScreen(restaurantId: 'r1', venue: _venue)),
    );
    await tester.pump(); // first frame: loading
    expect(find.byType(ListSkeleton), findsOneWidget);
  });

  testWidgets('the shell callbacks fire from the dashboard', (tester) async {
    usePhoneSurface(tester);
    String? status;
    String? hub;
    var reservations = false;
    await tester.pumpWidget(
      appShell(
        DashboardScreen(
          restaurantId: 'r1',
          venue: _venue,
          onOpenOrders: (value) => status = value,
          onOpenReservations: () => reservations = true,
          onOpenHub: (id) => hub = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dash_pipeline_pending')));
    expect(status, 'pending');

    await scrollDown(tester, 400);
    await tester.tap(find.byKey(const ValueKey('dash_alert_reservations')));
    expect(reservations, isTrue);
    expect(hub, isNull);
  });
}
