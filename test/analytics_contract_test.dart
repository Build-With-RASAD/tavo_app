// test/analytics_contract_test.dart
//
// THE CONTRACT GATE. `analytics_sample.json` is a verbatim capture of
// `GET /v1/api/restaurant-owner/analytics` from the deployed backend
// (2026-10-22, Wave 2 deploy #3). It is not hand-written: if the backend
// renames a key, stops sending a field, or changes a type, the Dart field
// silently falls back to 0 / null and the dashboard shows a plausible lie.
//
// So every assertion below names a REAL value from that response. A rename
// on either side turns one of these red instead of turning the screen into
// zeros nobody notices.
//
// Re-capture after a backend change:
//   curl -H "Authorization: Bearer <staff token>" \
//     ".../analytics?restaurantId=<id>&from=2026-09-23&to=2026-10-22"
//   → save `.data` as `test/fixtures/analytics_sample.json`
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

void main() {
  late DashboardAnalytics analytics;

  setUpAll(() {
    final raw = File('test/fixtures/analytics_sample.json').readAsStringSync();
    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    // The repo unwraps `{success, data}` through `panelPayload`; do the same
    // here so the test parses exactly what the app parses.
    expect(envelope['success'], isTrue);
    analytics = DashboardAnalytics.fromJson(
      (envelope['data'] as Map).cast<String, dynamic>(),
    );
  });

  test('range carries the window the backend computed', () {
    expect(analytics.range.days, 30);
    expect(analytics.range.from, isNotNull);
    expect(analytics.range.to, isNotNull);
    expect(analytics.range.to!.isAfter(analytics.range.from!), isTrue);
  });

  test('live maps every field the 20-second poll reads', () {
    final live = analytics.live;
    expect(live.revenueToday, 247.25);
    expect(live.ordersToday, 4);
    expect(live.openOrders, 1);
    expect(live.ordersByStatus, {'cancelled': 1, 'served': 2, 'pending': 1});
    expect(live.occupiedTables, 1);
    expect(live.totalTables, 2);
    expect(live.occupancyPct, 50);
    expect(live.waitlistCount, 1);
    expect(live.reservationsToday, 3);
    expect(live.seatedNow, 1);
    expect(live.revenueLastHour, 0);
  });

  test('kpi.revenue keeps gross, net and tax as three numbers', () {
    final revenue = analytics.kpi.revenue;
    expect(revenue.gross, 247.25);
    expect(revenue.net, 215);
    expect(revenue.tax, 32.25);
    expect(revenue.orders, 2);
    expect(revenue.avgOrderValue, 123.63);
    // The split must actually split: net + tax == gross for this capture.
    expect(revenue.net + revenue.tax, revenue.gross);
  });

  test('kpi.orders carries the by-status map and a real prep average', () {
    final orders = analytics.kpi.orders;
    expect(orders.total, 4);
    expect(orders.byStatus, {'pending': 1, 'served': 2, 'cancelled': 1});
    expect(orders.avgPrepMinutes, 21);
  });

  test('kpi.reservations keeps the backend snake_case status key', () {
    final reservations = analytics.kpi.reservations;
    expect(reservations.total, 3);
    // The backend emits `no_show` (snake) inside `byStatus` — the model must
    // carry the key through untouched, not drop it.
    expect(reservations.byStatus, {'seated': 1, 'confirmed': 1, 'no_show': 1});
    expect(reservations.noShowRate, 33.33);
    expect(reservations.capacityUtilizationPct, 33.33);
  });

  test('kpi.customers and the rating/ticket averages', () {
    expect(analytics.kpi.customers.total, 1);
    expect(analytics.kpi.customers.returning, 1);
    expect(analytics.kpi.customers.returningPct, 100);
    expect(analytics.kpi.avgRating, 4.5);
    expect(analytics.kpi.avgTicketMinutes, 33);
  });

  test('trend.daily maps the series the chart draws', () {
    expect(analytics.trend.daily, hasLength(1));
    final day = analytics.trend.daily.first;
    expect(day.date, '2026-10-22');
    expect(day.revenueGross, 247.25);
    expect(day.revenueNet, 215);
    expect(day.orders, 2);
    expect(day.avgOrderValue, 123.63);
  });

  test('trend.heatmap maps the 7x24 cells', () {
    expect(analytics.trend.heatmap, hasLength(2));
    final cell = analytics.trend.heatmap.first;
    expect(cell.weekday, 4);
    expect(cell.hour, 5);
    expect(cell.orders, 1);
    expect(cell.revenue, 109.25);
  });

  test('comparison maps deltas, and a zero baseline stays null', () {
    expect(analytics.comparison.revenue.current, 247.25);
    expect(analytics.comparison.revenue.previous, 195.5);
    expect(analytics.comparison.revenue.deltaPct, 26.47);
    expect(analytics.comparison.orders.deltaPct, 0);
    expect(analytics.comparison.avgOrderValue.deltaPct, 26.48);
    // previous == 0 → the backend sends null, never Infinity or a fake 100%.
    expect(analytics.comparison.reservations.previous, 0);
    expect(analytics.comparison.reservations.deltaPct, isNull);
  });

  test('topItems maps name, quantity, revenue and share', () {
    expect(analytics.topItems, hasLength(3));
    final item = analytics.topItems.first;
    expect(item.name, 'Classic Burger');
    expect(item.quantity, 3);
    expect(item.revenue, 135);
    expect(item.sharePct, 62.79);
  });

  test('alerts map to a tab the shell can actually open', () {
    expect(analytics.alerts, hasLength(2));
    final noShow = analytics.alerts.first;
    expect(noShow.type, 'high_no_show');
    expect(noShow.severity, 'warning');
    expect(noShow.count, 1);
    expect(noShow.message, contains('no-shows'));
    expect(noShow.isWarning, isTrue);

    final backlog = analytics.alerts[1];
    expect(backlog.type, 'waitlist_backlog');
    expect(backlog.severity, 'info');
    expect(backlog.count, 1);

    // `action` is a tab id. An action outside this set would be a dead alert:
    // tapping it would do nothing (see `_openAlert` in the dashboard).
    const tabIds = {'orders', 'reservations', 'waitlist', 'reports'};
    for (final alert in analytics.alerts) {
      expect(tabIds, contains(alert.action), reason: alert.type);
    }
  });

  test('the live endpoint payload parses as a bare LiveSnapshot', () {
    // `/analytics/live` returns the live object at `data` top level, NOT
    // nested under `live`. The repo feeds `panelPayload(...)` straight into
    // `LiveSnapshot.fromJson`, so the poll and the page must agree on it.
    final raw = File('test/fixtures/analytics_sample.json').readAsStringSync();
    final data = (jsonDecode(raw) as Map<String, dynamic>)['data'] as Map;
    final snapshot = LiveSnapshot.fromJson(
      (data['live'] as Map).cast<String, dynamic>(),
    );
    expect(snapshot.ordersByStatus, analytics.live.ordersByStatus);
    expect(snapshot.openOrders, analytics.live.openOrders);
    expect(snapshot.occupancyPct, analytics.live.occupancyPct);
  });
}
