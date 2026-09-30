// lib/feature/panel_menu/di/register_menu_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_menu/data/repo/menu_panel_repo.dart';
import 'package:tavo/feature/panel_menu/ui/screens/panel_menu_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_menu/di/register_menu_module.dart';
///   registerMenuModule();
///
/// Registers [MenuPanelRepo] and swaps the `menu` hub placeholder for the
/// real screen ([MoreHubRegistry.register] replaces by id, so calling this
/// twice never duplicates the tile; the repo guard makes re-runs safe too).
void registerMenuModule() {
  if (!getIt.isRegistered<MenuPanelRepo>()) {
    getIt.registerLazySingleton<MenuPanelRepo>(
        () => MenuPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'menu',
    labelKey: 'menu',
    icon: Icons.restaurant_menu_outlined,
    builder: (restaurantId, venue) => PanelMenuScreen(
      restaurantId: restaurantId,
      venue: venue,
      canManage: () =>
          venue.role == 'owner' ||
          venue.role == 'manager' ||
          venue.permissions.contains('full_access') ||
          venue.permissions.contains('manage_menu'),
    ),
  ));
}
