import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';

/// Re-exported so a single `dashboard_state.dart` import gives consumers the
/// full payload type ([DashboardStats]) the panel screen renders.
export 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';

/// Dashboard lifecycle: [DashboardInitial] → [DashboardLoading] →
/// [DashboardLoaded] on success or [DashboardError] (plain message, matching
/// `RestaurantPanelRepo`'s error style) on failure.
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;

  DashboardLoaded(this.stats);
}

class DashboardError extends DashboardState {
  final String message;

  DashboardError(this.message);
}
