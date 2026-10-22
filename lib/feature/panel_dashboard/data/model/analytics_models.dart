// lib/feature/panel_dashboard/data/model/analytics_models.dart
//
// Typed models for the analytics contract (spec §"New backend contracts"):
//
//   GET /v1/api/restaurant-owner/analytics?restaurantId=&from=&to=
//     { range, live, kpi, trend, comparison, topItems[], alerts[] }
//
//   GET /v1/api/restaurant-owner/analytics/live?restaurantId=
//     { …the `live` object only… }
//
// Every `fromJson` TOLERATES a missing key: it falls back to 0 / null / an
// empty collection and never throws. A partial payload must degrade to
// zeros, not crash the middle of the dashboard.

/// The window the business zone reports on.
///
/// [from] / [to] are the inclusive window bounds; `to` is the END of the
/// last day so the range covers the whole day.
enum AnalyticsRange {
  today,
  last7Days,
  last30Days,
  thisMonth,
  custom;

  /// i18n key of the selector chip.
  String get labelKey => switch (this) {
        AnalyticsRange.today => 'dash_range_today',
        AnalyticsRange.last7Days => 'dash_range_7d',
        AnalyticsRange.last30Days => 'dash_range_30d',
        AnalyticsRange.thisMonth => 'dash_range_month',
        AnalyticsRange.custom => 'dash_range_custom',
      };

  /// First day of the window (inclusive).
  DateTime from([DateTime? now]) {
    final n = _reference(now);
    // The DateTime constructor normalises the day overflow and keeps the
    // local midnight — subtracting a Duration would drift across a DST
    // switch.
    return switch (this) {
      AnalyticsRange.today => DateTime(n.year, n.month, n.day),
      AnalyticsRange.last7Days => DateTime(n.year, n.month, n.day - 6),
      AnalyticsRange.last30Days => DateTime(n.year, n.month, n.day - 29),
      AnalyticsRange.thisMonth => DateTime(n.year, n.month, 1),
      // A custom range carries its own bounds; this is the fallback.
      AnalyticsRange.custom => DateTime(n.year, n.month, n.day),
    };
  }

  /// Last day of the window (inclusive), at the end of the day.
  DateTime to([DateTime? now]) {
    final n = _reference(now);
    return DateTime(n.year, n.month, n.day, 23, 59, 59);
  }

  static DateTime _reference(DateTime? now) => now ?? DateTime.now();
}

/// `range` — the window the payload was computed for.
class AnalyticsRangeInfo {
  const AnalyticsRangeInfo({this.from, this.to, this.days = 0});

  final DateTime? from;
  final DateTime? to;
  final int days;

  factory AnalyticsRangeInfo.fromJson(Map<String, dynamic> json) {
    return AnalyticsRangeInfo(
      from: _date(json['from']),
      to: _date(json['to']),
      days: _int(json['days']),
    );
  }
}

/// `live` — the cheap snapshot the 20-second poll reads.
class LiveSnapshot {
  const LiveSnapshot({
    this.revenueToday = 0,
    this.ordersToday = 0,
    this.openOrders = 0,
    this.ordersByStatus = const {},
    this.occupiedTables = 0,
    this.totalTables = 0,
    this.occupancyPct = 0,
    this.waitlistCount = 0,
    this.reservationsToday = 0,
    this.seatedNow = 0,
    this.revenueLastHour = 0,
  });

  final double revenueToday;
  final int ordersToday;
  final int openOrders;
  final Map<String, int> ordersByStatus;
  final int occupiedTables;
  final int totalTables;
  final double occupancyPct;
  final int waitlistCount;
  final int reservationsToday;
  final int seatedNow;
  final double revenueLastHour;

  factory LiveSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveSnapshot(
      revenueToday: _double(json['revenueToday']),
      ordersToday: _int(json['ordersToday']),
      openOrders: _int(json['openOrders']),
      ordersByStatus: _intMap(json['ordersByStatus']),
      occupiedTables: _int(json['occupiedTables']),
      totalTables: _int(json['totalTables']),
      occupancyPct: _double(json['occupancyPct']),
      waitlistCount: _int(json['waitlistCount']),
      reservationsToday: _int(json['reservationsToday']),
      seatedNow: _int(json['seatedNow']),
      revenueLastHour: _double(json['revenueLastHour']),
    );
  }
}

/// `kpi.revenue` — gross / net / tax are three SEPARATE numbers
/// (spec decision 4: promo credit and wallet balances are owed money, not
/// revenue).
class RevenueKpi {
  const RevenueKpi({
    this.gross = 0,
    this.net = 0,
    this.tax = 0,
    this.orders = 0,
    this.avgOrderValue = 0,
  });

  final double gross;
  final double net;
  final double tax;
  final int orders;
  final double avgOrderValue;

  factory RevenueKpi.fromJson(Map<String, dynamic> json) {
    return RevenueKpi(
      gross: _double(json['gross']),
      net: _double(json['net']),
      tax: _double(json['tax']),
      orders: _int(json['orders']),
      avgOrderValue: _double(json['avgOrderValue']),
    );
  }
}

/// `kpi.orders` — [avgPrepMinutes] is null when no order carries the
/// lifecycle timestamps (spec decision 6: never zero-filled).
class OrdersKpi {
  const OrdersKpi({
    this.total = 0,
    this.byStatus = const {},
    this.avgPrepMinutes,
  });

  final int total;
  final Map<String, int> byStatus;
  final double? avgPrepMinutes;

  factory OrdersKpi.fromJson(Map<String, dynamic> json) {
    return OrdersKpi(
      total: _int(json['total']),
      byStatus: _intMap(json['byStatus']),
      avgPrepMinutes: _doubleOrNull(json['avgPrepMinutes']),
    );
  }
}

/// `kpi.reservations`.
class ReservationsKpi {
  const ReservationsKpi({
    this.total = 0,
    this.byStatus = const {},
    this.noShowRate,
    this.capacityUtilizationPct,
  });

  final int total;
  final Map<String, int> byStatus;
  final double? noShowRate;
  final double? capacityUtilizationPct;

  factory ReservationsKpi.fromJson(Map<String, dynamic> json) {
    return ReservationsKpi(
      total: _int(json['total']),
      byStatus: _intMap(json['byStatus']),
      noShowRate: _doubleOrNull(json['noShowRate']),
      capacityUtilizationPct: _doubleOrNull(json['capacityUtilizationPct']),
    );
  }
}

/// `kpi.customers` — [returningPct] is null when there is no customer yet.
class CustomersKpi {
  const CustomersKpi({this.total = 0, this.returning = 0, this.returningPct});

  final int total;
  final int returning;
  final double? returningPct;

  factory CustomersKpi.fromJson(Map<String, dynamic> json) {
    return CustomersKpi(
      total: _int(json['total']),
      returning: _int(json['returning']),
      returningPct: _doubleOrNull(json['returningPct']),
    );
  }
}

/// `kpi` — the range-scoped headline numbers.
class AnalyticsKpi {
  const AnalyticsKpi({
    this.revenue = const RevenueKpi(),
    this.orders = const OrdersKpi(),
    this.reservations = const ReservationsKpi(),
    this.customers = const CustomersKpi(),
    this.avgRating,
    this.avgTicketMinutes,
  });

  final RevenueKpi revenue;
  final OrdersKpi orders;
  final ReservationsKpi reservations;
  final CustomersKpi customers;
  final double? avgRating;
  final double? avgTicketMinutes;

  factory AnalyticsKpi.fromJson(Map<String, dynamic> json) {
    return AnalyticsKpi(
      revenue: RevenueKpi.fromJson(_map(json['revenue'])),
      orders: OrdersKpi.fromJson(_map(json['orders'])),
      reservations: ReservationsKpi.fromJson(_map(json['reservations'])),
      customers: CustomersKpi.fromJson(_map(json['customers'])),
      avgRating: _doubleOrNull(json['avgRating']),
      avgTicketMinutes: _doubleOrNull(json['avgTicketMinutes']),
    );
  }
}

/// One day of `trend.daily`.
class TrendPoint {
  const TrendPoint({
    this.date = '',
    this.revenueGross = 0,
    this.revenueNet = 0,
    this.orders = 0,
    this.avgOrderValue = 0,
  });

  final String date;
  final double revenueGross;
  final double revenueNet;
  final int orders;
  final double avgOrderValue;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date']?.toString() ?? '',
      revenueGross: _double(json['revenueGross']),
      revenueNet: _double(json['revenueNet']),
      orders: _int(json['orders']),
      avgOrderValue: _double(json['avgOrderValue']),
    );
  }
}

/// One cell of `trend.heatmap` — weekday 0–6, hour 0–23.
class HeatmapCell {
  const HeatmapCell({
    this.weekday = 0,
    this.hour = 0,
    this.orders = 0,
    this.revenue = 0,
  });

  final int weekday;
  final int hour;
  final int orders;
  final double revenue;

  factory HeatmapCell.fromJson(Map<String, dynamic> json) {
    return HeatmapCell(
      weekday: _int(json['weekday']),
      hour: _int(json['hour']),
      orders: _int(json['orders']),
      revenue: _double(json['revenue']),
    );
  }
}

/// `trend` — the daily series plus the 7 × 24 peak-hours grid.
class AnalyticsTrend {
  const AnalyticsTrend({this.daily = const [], this.heatmap = const []});

  final List<TrendPoint> daily;
  final List<HeatmapCell> heatmap;

  factory AnalyticsTrend.fromJson(Map<String, dynamic> json) {
    return AnalyticsTrend(
      daily: _mapList(json['daily']).map(TrendPoint.fromJson).toList(),
      heatmap: _mapList(json['heatmap']).map(HeatmapCell.fromJson).toList(),
    );
  }
}

/// One comparison metric — [deltaPct] is null when the previous period was
/// zero (never Infinity, never a fake 100%).
class ComparisonMetric {
  const ComparisonMetric({
    this.current = 0,
    this.previous = 0,
    this.deltaPct,
  });

  final double current;
  final double previous;
  final double? deltaPct;

  factory ComparisonMetric.fromJson(Map<String, dynamic> json) {
    return ComparisonMetric(
      current: _double(json['current']),
      previous: _double(json['previous']),
      deltaPct: _doubleOrNull(json['deltaPct']),
    );
  }
}

/// `comparison` — the current window against the preceding window of the
/// same length.
class AnalyticsComparison {
  const AnalyticsComparison({
    this.revenue = const ComparisonMetric(),
    this.orders = const ComparisonMetric(),
    this.avgOrderValue = const ComparisonMetric(),
    this.reservations = const ComparisonMetric(),
  });

  final ComparisonMetric revenue;
  final ComparisonMetric orders;
  final ComparisonMetric avgOrderValue;
  final ComparisonMetric reservations;

  factory AnalyticsComparison.fromJson(Map<String, dynamic> json) {
    return AnalyticsComparison(
      revenue: ComparisonMetric.fromJson(_map(json['revenue'])),
      orders: ComparisonMetric.fromJson(_map(json['orders'])),
      avgOrderValue: ComparisonMetric.fromJson(_map(json['avgOrderValue'])),
      reservations: ComparisonMetric.fromJson(_map(json['reservations'])),
    );
  }
}

/// One row of `topItems`.
class TopItem {
  const TopItem({
    this.name = '',
    this.quantity = 0,
    this.revenue = 0,
    this.sharePct = 0,
  });

  final String name;
  final int quantity;
  final double revenue;
  final double sharePct;

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      name: json['name']?.toString() ?? '',
      quantity: _int(json['quantity']),
      revenue: _double(json['revenue']),
      sharePct: _double(json['sharePct']),
    );
  }
}

/// One row of `alerts` — [action] names the tab that RESOLVES it
/// (the backend emits `orders`, `reservations`, `waitlist`, `reports`).
class AnalyticsAlert {
  const AnalyticsAlert({
    this.type = '',
    this.severity = '',
    this.message = '',
    this.count = 0,
    this.action = '',
  });

  final String type;
  final String severity;
  final String message;
  final int count;
  final String action;

  /// `critical` / `warning` / `info` — unknown values read as `info`.
  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';

  factory AnalyticsAlert.fromJson(Map<String, dynamic> json) {
    return AnalyticsAlert(
      type: json['type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      count: _int(json['count']),
      action: json['action']?.toString() ?? '',
    );
  }
}

/// The whole `/analytics` payload.
class DashboardAnalytics {
  const DashboardAnalytics({
    this.range = const AnalyticsRangeInfo(),
    this.live = const LiveSnapshot(),
    this.kpi = const AnalyticsKpi(),
    this.trend = const AnalyticsTrend(),
    this.comparison = const AnalyticsComparison(),
    this.topItems = const [],
    this.alerts = const [],
  });

  final AnalyticsRangeInfo range;
  final LiveSnapshot live;
  final AnalyticsKpi kpi;
  final AnalyticsTrend trend;
  final AnalyticsComparison comparison;
  final List<TopItem> topItems;
  final List<AnalyticsAlert> alerts;

  factory DashboardAnalytics.fromJson(Map<String, dynamic> json) {
    return DashboardAnalytics(
      range: AnalyticsRangeInfo.fromJson(_map(json['range'])),
      live: LiveSnapshot.fromJson(_map(json['live'])),
      kpi: AnalyticsKpi.fromJson(_map(json['kpi'])),
      trend: AnalyticsTrend.fromJson(_map(json['trend'])),
      comparison: AnalyticsComparison.fromJson(_map(json['comparison'])),
      topItems: _mapList(json['topItems']).map(TopItem.fromJson).toList(),
      alerts: _mapList(json['alerts']).map(AnalyticsAlert.fromJson).toList(),
    );
  }
}

// ===================== parsing helpers =====================

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

Map<String, int> _intMap(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) '${entry.key}': _int(entry.value),
  };
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _doubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
