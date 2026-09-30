// test/helpers/dashboard_extras_helper.dart
//
// Wave E2: DashboardScreen now also builds the extras section (quick
// actions, floor strip, waitlist preview, order chips) through
// registerDashboardModule(). Tests that pump the shell or the dashboard
// seed this dependency here — empty data, zero network.
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/dashboard_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';

/// Extras repo returning empty data: loads straight to the
/// loaded-but-empty state (quick actions + empty previews), no network.
class EmptyExtrasRepo extends DashboardPanelRepo {
  EmptyExtrasRepo() : super(api: ApiService());

  @override
  Future<List<PanelPhysicalTable>> getFloorTables(String restaurantId) async =>
      [];

  @override
  Future<({List<PanelWaitlistEntry> entries, int total})> getWaitlistPreview(
          String restaurantId) async =>
      (entries: <PanelWaitlistEntry>[], total: 0);

  @override
  Future<List<DashboardOpenOrder>> getOpenOrders(String restaurantId) async =>
      [];
}

/// Seed the dashboard-extras dependency (idempotent — respects anything the
/// test already registered). Call in setUp before pumping the shell.
void registerDashboardExtrasForTests() {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<DashboardPanelRepo>()) {
    getIt.registerLazySingleton<DashboardPanelRepo>(() => EmptyExtrasRepo());
  }
  registerDashboardModule();
}
