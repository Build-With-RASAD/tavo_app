// lib/feature/panel_dashboard/di/register_dashboard_module.dart
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
///   registerDashboardModule();
///
/// Dashboard is a shell TAB, not a hub module — registers the analytics repo
/// and the dashboard cubit only (no [MoreHubRegistry] tile; no badge side
/// effects).
void registerDashboardModule() {
  if (!getIt.isRegistered<AnalyticsPanelRepo>()) {
    getIt.registerLazySingleton<AnalyticsPanelRepo>(
      () => AnalyticsPanelRepo(api: getIt<ApiService>()),
    );
  }
  if (!getIt.isRegistered<DashboardCubit>()) {
    getIt.registerFactoryParam<DashboardCubit, String, void>(
      (restaurantId, _) => DashboardCubit(
        getIt<AnalyticsPanelRepo>(),
        restaurantId: restaurantId,
      ),
    );
  }
}
