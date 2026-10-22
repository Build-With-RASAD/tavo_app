// test/helpers/dashboard_analytics_helper.dart
//
// Wave 2 (Task 32): the dashboard reads the analytics endpoints. Tests that
// pump the shell or the dashboard seed this dependency here — empty data,
// zero network.
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';

/// Analytics repo returning empty data: loads straight to the
/// loaded-but-empty state (live band with zeros), no network. It records
/// the venue it was asked for so a test can assert which venue the
/// dashboard loaded.
class EmptyAnalyticsRepo extends AnalyticsPanelRepo {
  EmptyAnalyticsRepo() : super(api: ApiService());

  int analyticsCalls = 0;
  int liveCalls = 0;
  String? lastRestaurantId;

  @override
  Future<DashboardAnalytics> getAnalytics({
    required String restaurantId,
    required DateTime from,
    required DateTime to,
  }) async {
    analyticsCalls++;
    lastRestaurantId = restaurantId;
    return DashboardAnalytics.fromJson(const {});
  }

  @override
  Future<LiveSnapshot> getLiveSnapshot(String restaurantId) async {
    liveCalls++;
    lastRestaurantId = restaurantId;
    return LiveSnapshot.fromJson(const {});
  }
}

/// Seed the dashboard-analytics dependency (idempotent — respects anything
/// the test already registered). Call in setUp before pumping the shell.
void registerDashboardAnalyticsForTests() {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<AnalyticsPanelRepo>()) {
    getIt.registerLazySingleton<AnalyticsPanelRepo>(() => EmptyAnalyticsRepo());
  }
  registerDashboardModule();
}
