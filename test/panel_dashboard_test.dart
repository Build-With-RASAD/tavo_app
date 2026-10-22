// test/panel_dashboard_test.dart
//
// Wave 2 (Task 32): the dashboard module's repo + cubit + DI.
//
// Covered here:
//   * the DI registers the analytics repo and the cubit (no hub tile);
//   * the repo sends `restaurantId` on BOTH endpoints (the backend silently
//     falls back to the FIRST venue without it) and parses the envelope;
//   * a failing read becomes a readable message, never a crash;
//   * the poll merges the live snapshot instead of replacing the state, so
//     the page never flashes empty;
//   * the poll calls ONLY the cheap endpoint.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';

/// A dio-free api double.
class FakeApiService extends ApiService {
  dynamic getResponse;
  DioException? getError;

  /// When true, only the HEAVY endpoint fails — the cheap live endpoint
  /// keeps answering, so the live band survives.
  bool failHeavyOnly = false;
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;

  /// Every path that was read, in order.
  final List<String> getPaths = [];

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    getPaths.add(path);
    final isLive = path.endsWith('/analytics/live');
    if (getError != null && !(failHeavyOnly && isLive)) throw getError!;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: getResponse,
    );
  }
}

const _payload = {
  'success': true,
  'data': {
    'range': {'from': '2026-10-01', 'to': '2026-10-22', 'days': 22},
    'live': {'revenueToday': 100.5, 'openOrders': 3},
    'kpi': {'revenue': {'gross': 500}},
    'trend': {'daily': []},
    'topItems': [],
    'alerts': [],
  },
};

void main() {
  group('repo', () {
    late FakeApiService api;
    late AnalyticsPanelRepo repo;

    setUp(() {
      api = FakeApiService();
      repo = AnalyticsPanelRepo(api: api);
    });

    test('getAnalytics sends restaurantId, from and to', () async {
      api.getResponse = _payload;

      final analytics = await repo.getAnalytics(
        restaurantId: 'r1',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 22),
      );

      expect(api.lastGetPath, '/v1/api/restaurant-owner/analytics');
      expect(api.lastGetQuery!['restaurantId'], 'r1');
      expect(api.lastGetQuery!['from'], '2026-10-01');
      expect(api.lastGetQuery!['to'], '2026-10-22');
      expect(analytics.kpi.revenue.gross, 500);
      expect(analytics.live.openOrders, 3);
    });

    test('getLiveSnapshot hits the cheap endpoint with restaurantId',
        () async {
      api.getResponse = {
        'success': true,
        'data': {'revenueToday': 42.0, 'openOrders': 2},
      };

      final live = await repo.getLiveSnapshot('r7');

      expect(api.lastGetPath, '/v1/api/restaurant-owner/analytics/live');
      expect(api.lastGetQuery!['restaurantId'], 'r7');
      expect(live.revenueToday, 42.0);
      expect(live.openOrders, 2);
    });

    test('a missing payload degrades to zeros instead of throwing', () async {
      api.getResponse = {'success': true};

      final analytics = await repo.getAnalytics(
        restaurantId: 'r1',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 22),
      );
      final live = await repo.getLiveSnapshot('r1');

      expect(analytics.kpi.revenue.gross, 0);
      expect(live.revenueToday, 0);
    });

    test('a dio failure surfaces a readable message', () async {
      api.getError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      expect(
        repo.getLiveSnapshot('r1'),
        throwsA('No internet connection'),
      );
    });
  });

  group('cubit', () {
    test('the DI registers the repo and the cubit without a hub tile',
        () async {
      addTearDown(GetIt.instance.reset);
      registerDashboardModule();

      expect(GetIt.instance.isRegistered<AnalyticsPanelRepo>(), isTrue);
      expect(GetIt.instance.isRegistered<DashboardCubit>(), isTrue);
    });

    test('the poll merges the live snapshot and keeps the analytics',
        () async {
      final api = FakeApiService();
      api.getResponse = _payload;
      final cubit = DashboardCubit(
        AnalyticsPanelRepo(api: api),
        restaurantId: 'r1',
      );
      addTearDown(cubit.close);

      await cubit.load();
      final loaded = cubit.state as DashboardLoaded;
      expect(loaded.analytics, isNotNull);
      expect(loaded.live, isNotNull);

      api.getResponse = {
        'success': true,
        'data': {'revenueToday': 999.0},
      };
      await cubit.refreshLive();

      final merged = cubit.state as DashboardLoaded;
      expect(merged.analytics, isNotNull, reason: 'the page must not blank');
      expect(merged.analytics!.kpi.revenue.gross, 500);
      expect(merged.live!.revenueToday, 999.0);
    });

    test('the poll never calls the heavy endpoint', () async {
      final api = FakeApiService();
      api.getResponse = _payload;
      final cubit = DashboardCubit(
        AnalyticsPanelRepo(api: api),
        restaurantId: 'r1',
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(
        api.getPaths
            .where((path) => path.endsWith('/analytics'))
            .length,
        1,
      );

      await cubit.refreshLive();
      await cubit.refreshLive();

      expect(
        api.getPaths
            .where((path) => path.endsWith('/analytics'))
            .length,
        1,
        reason: 'the heavy endpoint must not run on every poll',
      );
      expect(
        api.getPaths
            .where((path) => path.endsWith('/analytics/live'))
            .length,
        3,
      );
    });

    test('a failing heavy read keeps the live band alive', () async {
      final api = FakeApiService()..failHeavyOnly = true;
      api.getResponse = _payload;
      api.getError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      final cubit = DashboardCubit(
        AnalyticsPanelRepo(api: api),
        restaurantId: 'r1',
      );
      addTearDown(cubit.close);

      await cubit.load();

      final state = cubit.state as DashboardLoaded;
      expect(state.analytics, isNull);
      expect(state.analyticsError, isNotNull);
      expect(state.live, isNotNull,
          reason: 'the live band must survive a failing heavy endpoint');
    });
  });
}
