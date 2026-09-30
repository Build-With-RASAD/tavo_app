// lib/feature/panel_branches/di/register_branches_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_branches/data/repo/branches_panel_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/branches_screen.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_branches/di/register_branches_module.dart';
///   registerBranchesModule();
///
/// Registers [BranchesPanelRepo] and swaps the `branches` hub placeholder
/// for the real screen ([MoreHubRegistry.register] replaces by id, so
/// calling this twice never duplicates the tile; the repo guard makes
/// re-runs safe too). The `manage_settings` gate lives inside the screen
/// via `venue`.
void registerBranchesModule() {
  if (!getIt.isRegistered<BranchesPanelRepo>()) {
    getIt.registerLazySingleton<BranchesPanelRepo>(
        () => BranchesPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'branches',
    labelKey: 'branches',
    icon: Icons.store_outlined,
    builder: (restaurantId, venue) =>
        BranchesScreen(restaurantId: restaurantId, venue: venue),
  ));
}
