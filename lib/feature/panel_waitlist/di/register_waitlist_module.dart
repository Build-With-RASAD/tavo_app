// lib/feature/panel_waitlist/di/register_waitlist_module.dart
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_waitlist/data/repo/waitlist_panel_repo.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_waitlist/di/register_waitlist_module.dart';
///   registerWaitlistModule();
/// No hub tile: the waitlist is a shell tab (Task 11 wired it already).
void registerWaitlistModule() {
  getIt.registerLazySingleton<WaitlistPanelRepo>(
      () => WaitlistPanelRepo(api: getIt<ApiService>()));
}
