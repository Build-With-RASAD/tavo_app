// lib/feature/panel_reviews/data/model/experience_summary.dart
//
// Wire model for `GET /experience-ratings/summary` — the real 0–5 business
// rating built from guest ratings at the table, not from the legacy review
// list. Parsing is deliberately tolerant: a missing area reads as `null`
// (no opinion yet) rather than 0.0, so an empty area is never mistaken for a
// one-star score.

/// One waiter's guest-rating average.
class WaiterScore {
  const WaiterScore({
    required this.staffId,
    required this.name,
    required this.average,
    required this.count,
  });

  final String staffId;
  final String name;
  final double average;
  final int count;

  factory WaiterScore.fromJson(Map<String, dynamic> json) => WaiterScore(
        staffId: json['staffId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        average: _toDouble(json['average']),
        count: _toInt(json['count']),
      );
}

class ExperienceSummary {
  const ExperienceSummary({
    required this.count,
    required this.scored,
    required this.average,
    required this.areas,
    required this.byType,
    required this.openComplaints,
    required this.waiters,
  });

  static const List<String> areaKeys = [
    'restaurant',
    'waiter',
    'food',
    'speed',
    'cleanliness',
  ];

  /// Every rating document, scored or not.
  final int count;

  /// Ratings that actually carried scores.
  final int scored;

  /// Mean of the five area averages; null when nothing was scored yet.
  final double? average;

  /// Area → average (null = no scores for that area).
  final Map<String, double?> areas;

  /// `review` / `complaint` / `suggestion` counts.
  final Map<String, int> byType;

  final int openComplaints;

  /// Highest average first, as the backend sorts them.
  final List<WaiterScore> waiters;

  bool get hasScores => average != null && scored > 0;

  factory ExperienceSummary.fromJson(Map<String, dynamic> json) {
    final rawAreas = json['areas'];
    final rawByType = json['byType'];
    final rawWaiters = json['waiters'];

    return ExperienceSummary(
      count: _toInt(json['count']),
      scored: _toInt(json['scored']),
      average: json['average'] == null ? null : _toDouble(json['average']),
      areas: {
        for (final key in areaKeys)
          key: rawAreas is Map && rawAreas[key] != null
              ? _toDouble(rawAreas[key])
              : null,
      },
      byType: {
        for (final key in const ['review', 'complaint', 'suggestion'])
          key: rawByType is Map ? _toInt(rawByType[key]) : 0,
      },
      openComplaints: _toInt(json['openComplaints']),
      waiters: rawWaiters is List
          ? rawWaiters
              .whereType<Map>()
              .map((row) => WaiterScore.fromJson(Map<String, dynamic>.from(row)))
              .where((waiter) => waiter.count > 0)
              .toList()
          : const [],
    );
  }
}

int _toInt(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}') ?? 0;

double _toDouble(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse('${value ?? ''}') ?? 0;
