// lib/feature/panel_dashboard/ui/logic/dashboard_state.dart
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

export 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

/// The dashboard lifecycle: [DashboardInitial] → [DashboardLoading] →
/// [DashboardLoaded] (the steady state) or [DashboardError] (nothing at all
/// could be read).
///
/// [DashboardLoaded] carries the two payloads SEPARATELY — the range-scoped
/// [analytics] and the polled [live] snapshot — so that one failing read
/// degrades a single section instead of collapsing the page (spec decision
/// 14).
sealed class DashboardState {
  const DashboardState();
}

/// Nothing has been requested yet.
class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

/// The first read is in flight — the screen shows a skeleton.
class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

/// The steady state: at least one of the two reads succeeded.
class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.range,
    this.analytics,
    this.live,
    this.analyticsError,
    this.liveError,
    this.customFrom,
    this.customTo,
    this.refreshing = false,
  });

  /// The window the business zone reports on.
  final AnalyticsRange range;

  /// The heavy payload — null when the heavy read failed.
  final DashboardAnalytics? analytics;

  /// The polled snapshot — null until the first live read lands.
  final LiveSnapshot? live;

  /// The heavy read's failure — the business zone renders it inline.
  final String? analyticsError;

  /// The live read's failure — the live band renders it inline.
  final String? liveError;

  /// The custom window's bounds (only for [AnalyticsRange.custom]).
  final DateTime? customFrom;
  final DateTime? customTo;

  /// A refresh / range change is in flight — the content stays on screen.
  final bool refreshing;

  DashboardLoaded copyWith({
    AnalyticsRange? range,
    DashboardAnalytics? analytics,
    LiveSnapshot? live,
    String? analyticsError,
    String? liveError,
    DateTime? customFrom,
    DateTime? customTo,
    bool? refreshing,
    bool clearAnalyticsError = false,
    bool clearLiveError = false,
  }) {
    return DashboardLoaded(
      range: range ?? this.range,
      analytics: analytics ?? this.analytics,
      live: live ?? this.live,
      analyticsError:
          clearAnalyticsError ? null : analyticsError ?? this.analyticsError,
      liveError: clearLiveError ? null : liveError ?? this.liveError,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

/// Neither read could be served — the whole screen is an error.
class DashboardError extends DashboardState {
  const DashboardError(this.message);

  final String message;
}
