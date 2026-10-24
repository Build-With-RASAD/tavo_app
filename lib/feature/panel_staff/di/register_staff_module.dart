// lib/feature/panel_staff/di/register_staff_module.dart
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_staff/data/repo/staff_panel_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/staff_screen.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_staff/di/register_staff_module.dart';
///   registerStaffModule();
///
/// Registers [StaffPanelRepo] and swaps the `staff` hub placeholder for the
/// real screen ([MoreHubRegistry.register] replaces by id, so calling this
/// twice never duplicates the tile; the repo guard makes re-runs safe too).
void registerStaffModule() {
  if (!getIt.isRegistered<StaffPanelRepo>()) {
    getIt.registerLazySingleton<StaffPanelRepo>(
        () => StaffPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'staff',
    labelKey: 'staff',
    icon: Iconsax.user_square,
    builder: (restaurantId, venue) => StaffScreen(
      restaurantId: restaurantId,
      venue: venue,
    ),
  ));
}
