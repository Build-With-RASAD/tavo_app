/// Parsed `GET /restaurant-owner/dashboard` payload for the panel home screen.
///
/// Every section and field tolerates missing keys: sections default to zeroed
/// sub-objects, numeric fields default to 0, strings to `''`.
class DashboardStats {
  const DashboardStats({
    required this.orders,
    required this.reservations,
    required this.revenue,
    required this.reviews,
  });

  final OrderTally orders;
  final ReservationTally reservations;
  final RevenueSummary revenue;
  final ReviewSummary reviews;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      orders: OrderTally.fromJson(_asMap(json['orders']) ?? const <String, dynamic>{}),
      reservations: ReservationTally.fromJson(
          _asMap(json['reservations']) ?? const <String, dynamic>{}),
      revenue: RevenueSummary.fromJson(
          _asMap(json['revenue']) ?? const <String, dynamic>{}),
      reviews: ReviewSummary.fromJson(
          _asMap(json['reviews']) ?? const <String, dynamic>{}),
    );
  }
}

/// Order counts by status plus the "new orders" count and average order value.
class OrderTally {
  const OrderTally({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.preparing = 0,
    this.ready = 0,
    this.delivered = 0,
    this.cancelled = 0,
    this.newCount = 0,
    this.avgOrderValue = 0,
  });

  final int total;
  final int pending;
  final int confirmed;
  final int preparing;
  final int ready;
  final int delivered;
  final int cancelled;

  /// Count behind the backend `newOrders` key — a list or an int is tolerated.
  final int newCount;

  final double avgOrderValue;

  factory OrderTally.fromJson(Map<String, dynamic> json) {
    return OrderTally(
      total: _toInt(json['total']),
      pending: _toInt(json['pending']),
      confirmed: _toInt(json['confirmed']),
      preparing: _toInt(json['preparing']),
      ready: _toInt(json['ready']),
      delivered: _toInt(json['delivered']),
      cancelled: _toInt(json['cancelled']),
      newCount: json['newOrders'] is List
          ? (json['newOrders'] as List).length
          : int.tryParse('${json['newOrders']}') ?? 0,
      avgOrderValue: _toDouble(json['avgOrderValue']),
    );
  }
}

/// Reservation counts by status.
class ReservationTally {
  const ReservationTally({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.seated = 0,
    this.completed = 0,
    this.noShow = 0,
    this.cancelled = 0,
  });

  final int total;
  final int pending;
  final int confirmed;
  final int seated;
  final int completed;
  final int noShow;
  final int cancelled;

  factory ReservationTally.fromJson(Map<String, dynamic> json) {
    return ReservationTally(
      total: _toInt(json['total']),
      pending: _toInt(json['pending']),
      confirmed: _toInt(json['confirmed']),
      seated: _toInt(json['seated']),
      completed: _toInt(json['completed']),
      noShow: _toInt(json['noShow']),
      cancelled: _toInt(json['cancelled']),
    );
  }
}

/// Revenue totals: all-time and current month.
class RevenueSummary {
  const RevenueSummary({
    this.total = 0,
    this.thisMonth = 0,
  });

  final double total;
  final double thisMonth;

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    return RevenueSummary(
      total: _toDouble(json['total']),
      thisMonth: _toDouble(json['thisMonth']),
    );
  }
}

/// Average rating plus the most recent reviews.
class ReviewSummary {
  const ReviewSummary({
    this.averageRating = 0,
    this.recent = const [],
  });

  final double averageRating;
  final List<RecentReview> recent;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final recent = json['recent'];
    return ReviewSummary(
      averageRating: _toDouble(json['averageRating']),
      recent: recent is List
          ? recent
              .map((e) =>
                  RecentReview.fromJson(_asMap(e) ?? const <String, dynamic>{}))
              .toList()
          : const [],
    );
  }
}

/// One entry of `reviews.recent` — `userName` comes from `user.name`.
class RecentReview {
  const RecentReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.userName,
  });

  final String id;
  final int rating;
  final String comment;
  final String createdAt;
  final String userName;

  factory RecentReview.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);
    return RecentReview(
      id: json['_id']?.toString() ?? '',
      rating: _toInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      userName: user?['name']?.toString() ?? '',
    );
  }
}

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _toInt(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}') ?? 0;

double _toDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? ''}') ?? 0;
