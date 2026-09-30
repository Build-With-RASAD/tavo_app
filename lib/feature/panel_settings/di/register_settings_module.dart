// lib/feature/panel_settings/di/register_settings_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_settings/data/repo/settings_panel_repo.dart';
import 'package:tavo/feature/panel_settings/ui/screens/panel_settings_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_settings/di/register_settings_module.dart';
///   registerSettingsModule();
///
/// Registers [SettingsPanelRepo] and swaps the `settings` hub placeholder
/// for the real screen ([MoreHubRegistry.register] replaces by id, so
/// calling this twice never duplicates the tile; the repo guard makes
/// re-runs safe too).
void registerSettingsModule() {
  if (!getIt.isRegistered<SettingsPanelRepo>()) {
    getIt.registerLazySingleton<SettingsPanelRepo>(
        () => SettingsPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'settings',
    labelKey: 'settings',
    icon: Icons.settings_outlined,
    builder: (restaurantId, venue) => PanelSettingsScreen(
      restaurantId: restaurantId,
      venue: venue,
      canManage: () =>
          venue.role == 'owner' ||
          venue.role == 'manager' ||
          venue.permissions.contains('full_access') ||
          venue.permissions.contains('manage_settings'),
    ),
  ));
}
