// test/panel_dashboard_v2_test.dart
//
// Wave 2 — Task 32: the dashboard rebuild into a full management system.
//
// Covered (the brief's contract):
//   * the analytics models tolerate MISSING optional keys (0 / null / empty)
//     and parse the frozen sample response verbatim;
//   * changing the range calls the repo again with the new from / to;
//   * section error isolation — one failing section never blanks the page;
//   * the KPI tiles render the values from the payload;
//   * the charts render without throwing (line, bar, heatmap, top items);
//   * tapping an alert fires its callback with the alert's `action`;
//   * tapping the occupancy tile fires the occupancy callback;
//   * reduced motion still renders every value;
//   * RTL flips the heatmap and the bar order.
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/alert_rail.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/comparison_row.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/date_range_selector.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/kpi_tiles.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/live_hero_band.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/management_shortcuts.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/occupancy_ring.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/order_pipeline.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/orders_volume_chart.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/peak_hours_heatmap.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/section_error_boundary.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/top_items_chart.dart';

import 'helpers/app_shell.dart';

/// The sample response — Task 31-B's **verbatim** body (the `data` object
/// of `GET /v1/api/restaurant-owner/analytics`), copied from
/// `.superpowers/sdd/2026-10-22-restaurant-intelligence-wave2/task-31-b-report.md`
/// §2.1. The Dart models must parse exactly this.
const Map<String, dynamic> sampleAnalytics = {
  'range': {
    'from': '2026-09-22T21:00:00.000Z',
    'to': '2026-10-22T20:59:59.999Z',
    'days': 30,
  },
  'live': {
    'revenueToday': 247.25,
    'ordersToday': 4,
    'openOrders': 1,
    'ordersByStatus': {'cancelled': 1, 'served': 2, 'pending': 1},
    'occupiedTables': 1,
    'totalTables': 2,
    'occupancyPct': 50,
    'waitlistCount': 1,
    'reservationsToday': 3,
    'seatedNow': 1,
    'revenueLastHour': 0,
  },
  'kpi': {
    'revenue': {
      'gross': 247.25,
      'net': 215,
      'tax': 32.25,
      'orders': 2,
      'avgOrderValue': 123.63,
    },
    'orders': {
      'total': 4,
      'byStatus': {'pending': 1, 'served': 2, 'cancelled': 1},
      'avgPrepMinutes': 21,
    },
    'reservations': {
      'total': 3,
      'byStatus': {'seated': 1, 'confirmed': 1, 'no_show': 1},
      'noShowRate': 33.33,
      'capacityUtilizationPct': 33.33,
    },
    'customers': {'total': 1, 'returning': 1, 'returningPct': 100},
    'avgRating': 4.5,
    'avgTicketMinutes': 33,
  },
  'trend': {
    'daily': [
      {
        'date': '2026-10-22',
        'revenueGross': 247.25,
        'revenueNet': 215,
        'orders': 2,
        'avgOrderValue': 123.63,
      },
    ],
    'heatmap': [
      {'weekday': 4, 'hour': 5, 'orders': 1, 'revenue': 109.25},
      {'weekday': 4, 'hour': 7, 'orders': 1, 'revenue': 138},
    ],
  },
  'comparison': {
    'revenue': {'current': 247.25, 'previous': 195.5, 'deltaPct': 26.47},
    'orders': {'current': 2, 'previous': 2, 'deltaPct': 0},
    'avgOrderValue': {'current': 123.63, 'previous': 97.75, 'deltaPct': 26.48},
    'reservations': {'current': 3, 'previous': 0, 'deltaPct': null},
  },
  'topItems': [
    {'name': 'Classic Burger', 'quantity': 3, 'revenue': 135, 'sharePct': 62.79},
    {'name': 'Caesar Salad', 'quantity': 1, 'revenue': 50, 'sharePct': 23.26},
    {'name': 'French Fries', 'quantity': 1, 'revenue': 30, 'sharePct': 13.95},
  ],
  'alerts': [
    {
      'type': 'high_no_show',
      'severity': 'warning',
      'message': '33.33% of reservations were no-shows',
      'count': 1,
      'action': 'reservations',
    },
    {
      'type': 'waitlist_backlog',
      'severity': 'info',
      'message': '1 guests are waiting for a table',
      'count': 1,
      'action': 'waitlist',
    },
  ],
};

/// A repo double: records the requested range and answers from a fixture.
class _FakeAnalyticsRepo extends AnalyticsPanelRepo {
  _FakeAnalyticsRepo() : super(api: ApiService());

  DashboardAnalytics analytics = DashboardAnalytics.fromJson(sampleAnalytics);
  LiveSnapshot live = LiveSnapshot.fromJson(
    sampleAnalytics['live'] as Map<String, dynamic>);
  Object? analyticsError;
  Object? liveError;

  final List<({DateTime from, DateTime to})> analyticsCalls = [];
  int liveCalls = 0;

  @override
  Future<DashboardAnalytics> getAnalytics({
    required String restaurantId,
    required DateTime from,
    required DateTime to,
  }) async {
    analyticsCalls.add((from: from, to: to));
    if (analyticsError != null) throw analyticsError!;
    return analytics;
  }

  @override
  Future<LiveSnapshot> getLiveSnapshot(String restaurantId) async {
    liveCalls++;
    if (liveError != null) throw liveError!;
    return live;
  }
}

/// A dio-free api double for the repo tests.
class _FakeApiService extends ApiService {
  dynamic getResponse;
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: getResponse,
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(appShell(child));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnv);

  group('models', () {
    test('every model survives a missing payload without throwing', () {
      final analytics = DashboardAnalytics.fromJson(const {});
      expect(analytics.live.revenueToday, 0);
      expect(analytics.live.ordersByStatus, isEmpty);
      expect(analytics.kpi.revenue.gross, 0);
      expect(analytics.kpi.orders.avgPrepMinutes, isNull);
      expect(analytics.kpi.reservations.noShowRate, isNull);
      expect(analytics.kpi.customers.returningPct, isNull);
      expect(analytics.kpi.avgRating, isNull);
      expect(analytics.kpi.avgTicketMinutes, isNull);
      expect(analytics.trend.daily, isEmpty);
      expect(analytics.trend.heatmap, isEmpty);
      expect(analytics.comparison.revenue.deltaPct, isNull);
      expect(analytics.comparison.revenue.current, 0);
      expect(analytics.topItems, isEmpty);
      expect(analytics.alerts, isEmpty);
      expect(analytics.range.days, 0);
      expect(analytics.range.from, isNull);
    });

    test('a partial payload degrades to zeros instead of crashing', () {
      final analytics = DashboardAnalytics.fromJson(const {
        'live': {'revenueToday': 10},
        'kpi': {'revenue': {'gross': 99}},
      });
      expect(analytics.live.revenueToday, 10);
      expect(analytics.live.ordersToday, 0);
      expect(analytics.kpi.revenue.gross, 99);
      expect(analytics.kpi.revenue.net, 0);
      expect(analytics.kpi.orders.total, 0);
    });

    test('parses the frozen sample response verbatim', () {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      expect(analytics.range.days, 30);
      expect(analytics.range.from, isNotNull);
      expect(analytics.live.revenueToday, 247.25);
      expect(analytics.live.openOrders, 1);
      expect(analytics.live.occupancyPct, 50);
      expect(analytics.live.ordersByStatus['pending'], 1);
      expect(analytics.live.ordersByStatus['served'], 2);

      expect(analytics.kpi.revenue.gross, 247.25);
      expect(analytics.kpi.revenue.net, 215);
      expect(analytics.kpi.revenue.tax, 32.25);
      expect(analytics.kpi.revenue.orders, 2);
      expect(analytics.kpi.revenue.avgOrderValue, 123.63);
      expect(analytics.kpi.orders.total, 4);
      expect(analytics.kpi.orders.avgPrepMinutes, 21);
      expect(analytics.kpi.reservations.total, 3);
      expect(analytics.kpi.reservations.noShowRate, 33.33);
      // The wire key is the enum's own snake_case.
      expect(analytics.kpi.reservations.byStatus['no_show'], 1);
      expect(analytics.kpi.customers.returning, 1);
      expect(analytics.kpi.customers.returningPct, 100);
      expect(analytics.kpi.avgRating, 4.5);
      expect(analytics.kpi.avgTicketMinutes, 33);

      expect(analytics.trend.daily, hasLength(1));
      expect(analytics.trend.daily.first.revenueGross, 247.25);
      expect(analytics.trend.daily.first.date, '2026-10-22');
      expect(analytics.trend.heatmap, hasLength(2));
      expect(analytics.trend.heatmap.first.weekday, 4);
      expect(analytics.trend.heatmap.first.hour, 5);
      expect(analytics.trend.heatmap.last.hour, 7);

      expect(analytics.comparison.revenue.deltaPct, 26.47);
      expect(analytics.comparison.orders.previous, 2);
      // previous === 0 → null, never Infinity.
      expect(analytics.comparison.reservations.deltaPct, isNull);

      expect(analytics.topItems, hasLength(3));
      expect(analytics.topItems.first.name, 'Classic Burger');
      expect(analytics.topItems.first.sharePct, 62.79);

      expect(analytics.alerts, hasLength(2));
      expect(analytics.alerts.first.action, 'reservations');
      expect(analytics.alerts.first.severity, 'warning');
      expect(analytics.alerts.last.severity, 'info');
    });

    test('a null delta (previous period was zero) stays null', () {
      final analytics = DashboardAnalytics.fromJson(const {
        'comparison': {
          'revenue': {'current': 100, 'previous': 0, 'deltaPct': null},
        },
      });
      expect(analytics.comparison.revenue.deltaPct, isNull);
    });

    test('AnalyticsRange exposes from / to accessors', () {
      final now = DateTime(2026, 10, 22, 14, 30);
      expect(AnalyticsRange.today.from(now), DateTime(2026, 10, 22));
      expect(AnalyticsRange.today.to(now).day, 22);
      expect(AnalyticsRange.last7Days.from(now), DateTime(2026, 10, 16));
      expect(AnalyticsRange.last30Days.from(now), DateTime(2026, 9, 23));
      expect(AnalyticsRange.thisMonth.from(now), DateTime(2026, 10, 1));
      expect(AnalyticsRange.thisMonth.to(now).day, 22);
    });
  });

  group('cubit', () {
    test('changing the range refetches with the new from / to', () async {
      final repo = _FakeAnalyticsRepo();
      final cubit = DashboardCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      await cubit.load();
      expect(repo.analyticsCalls, hasLength(1));

      await cubit.setRange(AnalyticsRange.last7Days);
      expect(repo.analyticsCalls, hasLength(2));
      final first = repo.analyticsCalls.first;
      final second = repo.analyticsCalls.last;
      // A 7-day window (inclusive) that starts later than the 30-day one.
      expect(second.from.isAfter(first.from), isTrue);
      expect(second.to.difference(second.from).inDays, 6);
      expect(cubit.state is DashboardLoaded, isTrue);
    });

    test('the live poll merges into the loaded state without blanking it',
        () async {
      final repo = _FakeAnalyticsRepo();
      final cubit = DashboardCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      await cubit.load();
      final before = cubit.state as DashboardLoaded;
      expect(before.analytics, isNotNull);

      repo.live = LiveSnapshot.fromJson(const {
        'revenueToday': 999,
        'openOrders': 3,
      });
      await cubit.refreshLive();

      final after = cubit.state as DashboardLoaded;
      // The page is NOT blanked: the analytics payload survives the poll.
      expect(after.analytics, isNotNull);
      expect(after.analytics!.kpi.revenue.gross, 247.25);
      // …and the live object is the fresh one.
      expect(after.live!.revenueToday, 999);
      expect(after.live!.openOrders, 3);
    });

    test('the poll calls ONLY the live endpoint, never the heavy one',
        () async {
      final repo = _FakeAnalyticsRepo();
      final cubit = DashboardCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      await cubit.load();
      expect(repo.analyticsCalls, hasLength(1));

      await cubit.refreshLive();
      await cubit.refreshLive();
      expect(repo.analyticsCalls, hasLength(1),
          reason: 'the heavy /analytics endpoint must not run on every poll');
      expect(repo.liveCalls, 3);
    });

    test('a failing live poll keeps the page and records the error',
        () async {
      final repo = _FakeAnalyticsRepo();
      final cubit = DashboardCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      await cubit.load();
      repo.liveError = Exception('live down');
      await cubit.refreshLive();

      final state = cubit.state as DashboardLoaded;
      expect(state.analytics, isNotNull);
      expect(state.liveError, contains('live down'));
    });

    test('a failing analytics load keeps the live band alive', () async {
      final repo = _FakeAnalyticsRepo();
      final cubit = DashboardCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      repo.analyticsError = Exception('heavy down');
      await cubit.load();

      final state = cubit.state as DashboardLoaded;
      expect(state.analytics, isNull);
      expect(state.analyticsError, contains('heavy down'));
      expect(state.live, isNotNull,
          reason: 'the live band must survive a failing heavy endpoint');
    });
  });

  group('repo', () {
    test('getAnalytics sends restaurantId, from and to', () async {
      final api = _FakeApiService();
      final repo = AnalyticsPanelRepo(api: api);
      api.getResponse = {
        'success': true,
        'data': sampleAnalytics,
      };

      final analytics = await repo.getAnalytics(
        restaurantId: 'r1',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 22),
      );

      expect(api.lastGetPath, '/v1/api/restaurant-owner/analytics');
      expect(api.lastGetQuery!['restaurantId'], 'r1',
          reason: 'the backend silently falls back to the FIRST venue');
      expect(api.lastGetQuery!['from'], '2026-10-01');
      expect(api.lastGetQuery!['to'], '2026-10-22');
      expect(analytics.kpi.revenue.gross, 247.25);
    });

    test('getLiveSnapshot hits the cheap endpoint with restaurantId',
        () async {
      final api = _FakeApiService();
      final repo = AnalyticsPanelRepo(api: api);
      api.getResponse = {
        'success': true,
        'data': sampleAnalytics['live'],
      };

      final live = await repo.getLiveSnapshot('r1');

      expect(api.lastGetPath, '/v1/api/restaurant-owner/analytics/live');
      expect(api.lastGetQuery!['restaurantId'], 'r1');
      expect(live.revenueToday, 247.25);
      expect(live.ordersByStatus['served'], 2);
    });
  });

  group('widgets', () {
    testWidgets('the live hero band renders the live numbers', (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await _pump(
        tester,
        Scaffold(
          body: LiveHeroBand(
            live: analytics.live,
            sparkline: analytics.trend.daily,
            revenueDeltaPct: analytics.comparison.revenue.deltaPct,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('247.25'), findsOneWidget); // revenue today
      expect(find.text('50%'), findsOneWidget); // occupancy
      expect(find.text('+26.5%'), findsOneWidget); // the delta chip
      expect(find.text('1'), findsWidgets); // open orders + waitlist
    });

    testWidgets('the live band links every figure into the tab that acts on it',
        (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);
      var orders = false;
      var waitlist = false;
      var tables = false;

      await _pump(
        tester,
        Scaffold(
          body: LiveHeroBand(
            live: analytics.live,
            sparkline: analytics.trend.daily,
            onOpenOrders: () => orders = true,
            onOpenWaitlist: () => waitlist = true,
            onOpenTables: () => tables = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('dash_live_open_orders')));
      // The open-orders figure spans four statuses — the Orders tab opens
      // unfiltered (the pipeline carries the exact per-status links).
      expect(orders, isTrue);

      await tester.tap(find.byKey(const ValueKey('dash_live_waitlist')));
      expect(waitlist, isTrue);

      await tester.tap(find.byKey(const ValueKey('dash_live_occupancy')));
      expect(tables, isTrue);
    });

    testWidgets('the KPI tiles render the values from the payload',
        (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: KpiTiles(kpi: analytics.kpi),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('247.25'), findsOneWidget); // gross revenue
      expect(find.text('215.00'), findsOneWidget); // net revenue
      expect(find.text('4'), findsOneWidget); // orders
      expect(find.text('123.63'), findsOneWidget); // avg order value
      expect(find.text('4.5'), findsOneWidget); // avg rating
    });

    testWidgets('the order pipeline taps report the status', (tester) async {
      String? opened;
      await _pump(
        tester,
        Scaffold(
          body: OrderPipeline(
            ordersByStatus: const {'pending': 4, 'preparing': 2, 'ready': 1},
            onOpenOrders: (status) => opened = status,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('dash_pipeline_pending')));
      expect(opened, 'pending');
    });

    testWidgets('tapping the occupancy tile fires the occupancy callback',
        (tester) async {
      var tapped = false;
      await _pump(
        tester,
        Scaffold(
          body: OccupancyRing(
            occupied: 9,
            total: 18,
            onOpenTables: () => tapped = true,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('50%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dash_occupancy_ring')));
      expect(tapped, isTrue);
    });

    testWidgets('tapping an alert fires its callback with the action',
        (tester) async {
      String? action;
      final alerts = DashboardAnalytics.fromJson(sampleAnalytics).alerts;

      await _pump(
        tester,
        Scaffold(
          body: AlertRail(
            alerts: alerts,
            onOpenAlert: (value) => action = value,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('33.33% of reservations were no-shows'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dash_alert_reservations')));
      expect(action, 'reservations');
    });

    testWidgets('the charts render without throwing', (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                RevenueTrendChart(points: analytics.trend.daily),
                OrdersVolumeChart(points: analytics.trend.daily),
                PeakHoursHeatmap(cells: analytics.trend.heatmap),
                TopItemsChart(items: analytics.topItems),
                ComparisonRow(comparison: analytics.comparison),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RevenueTrendChart), findsOneWidget);
      expect(find.byType(OrdersVolumeChart), findsOneWidget);
      expect(find.byType(PeakHoursHeatmap), findsOneWidget);
      expect(find.byType(TopItemsChart), findsOneWidget);
      expect(find.byType(ComparisonRow), findsOneWidget);
      // The top-items chart shows the item name and its share.
      expect(find.text('Classic Burger'), findsOneWidget);
      expect(find.text('62.8%'), findsOneWidget);
    });

    testWidgets('the date range selector reports the picked range',
        (tester) async {
      AnalyticsRange? picked;
      await _pump(
        tester,
        Scaffold(
          body: DateRangeSelector(
            range: AnalyticsRange.last30Days,
            onChanged: (range) => picked = range,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('dash_range_today')));
      expect(picked, AnalyticsRange.today);
    });

    testWidgets('the management shortcuts report the hub id', (tester) async {
      String? hub;
      await _pump(
        tester,
        Scaffold(
          body: ManagementShortcuts(onOpenHub: (id) => hub = id),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('dash_shortcut_menu')));
      expect(hub, 'menu');
    });

    testWidgets('a failing section never blanks its siblings',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Column(
            children: [
              const Text('sibling survives'),
              SectionErrorBoundary(
                error: 'section blew up',
                onRetry: () {},
                builder: (context) => const Text('never rendered'),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('sibling survives'), findsOneWidget);
      expect(find.text('section blew up'), findsOneWidget);
      expect(find.text('never rendered'), findsNothing);
    });

    testWidgets('a section that throws renders its own error, not a crash',
        (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Column(
            children: [
              const Text('sibling survives'),
              SectionErrorBoundary(
                onRetry: () {},
                builder: (context) => throw StateError('boom'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('sibling survives'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('a live poll does not restart the chart animation',
        (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await _pump(
        tester,
        Scaffold(
          body: RevenueTrendChart(points: analytics.trend.daily),
        ),
      );

      final before = tester.widget<LineChart>(find.byType(LineChart)).data;

      // A poll rebuilds the tree with the SAME series (the poll only moves
      // the live snapshot): the chart data instance must stay identical, so
      // fl_chart does not animate the line back to zero.
      await _pump(
        tester,
        Scaffold(
          body: RevenueTrendChart(points: analytics.trend.daily),
        ),
      );

      final after = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(identical(before, after), isTrue);
    });

    testWidgets('reduced motion still renders every value', (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await tester.pumpWidget(
        appShell(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: LiveHeroBand(
                live: analytics.live,
                sparkline: analytics.trend.daily,
                revenueDeltaPct: analytics.comparison.revenue.deltaPct,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('247.25'), findsOneWidget);
      expect(find.text('+26.5%'), findsOneWidget);
    });

    testWidgets('LTR lays the heatmap out left to right', (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await _pump(
        tester,
        Scaffold(body: PeakHoursHeatmap(cells: analytics.trend.heatmap)),
      );

      expect(tester.takeException(), isNull);
      final hour5 = tester.getTopLeft(
        find.byKey(const ValueKey('dash_heatmap_4_5')),
      );
      final hour7 = tester.getTopLeft(
        find.byKey(const ValueKey('dash_heatmap_4_7')),
      );
      expect(hour5.dx, lessThan(hour7.dx));
    });

    testWidgets('RTL flips the heatmap hours and the bar order',
        (tester) async {
      final analytics = DashboardAnalytics.fromJson(sampleAnalytics);

      await tester.pumpWidget(
        appShell(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ListView(
                children: [
                  PeakHoursHeatmap(cells: analytics.trend.heatmap),
                  TopItemsChart(items: analytics.topItems),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The heatmap row mirrors: hour 5 sits to the RIGHT of hour 7.
      final hour5 = tester.getTopLeft(
        find.byKey(const ValueKey('dash_heatmap_4_5')),
      );
      final hour7 = tester.getTopLeft(
        find.byKey(const ValueKey('dash_heatmap_4_7')),
      );
      expect(hour5.dx, greaterThan(hour7.dx));

      // The top-items bars grow from the RIGHT (the RTL start side). The first
      // item owns the biggest share, so the SECOND bar is the one that
      // shows the start side.
      final bar = tester.getRect(
        find.byKey(const ValueKey('dash_top_bar_1')),
      );
      final row = tester.getRect(
        find.byKey(const ValueKey('dash_top_row_1')),
      );
      expect(bar.left, greaterThan(row.left));
      expect(bar.right, lessThanOrEqualTo(row.right + 0.01));
    });
  });
}
