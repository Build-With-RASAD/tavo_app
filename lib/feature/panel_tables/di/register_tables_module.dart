// lib/feature/panel_tables/di/register_tables_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/tables_screen.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_tables/di/register_tables_module.dart';
///   registerTablesModule();
///
/// Registers [TablesPanelRepo] and swaps the `tables` hub placeholder for
/// the real screen ([MoreHubRegistry.register] replaces by id, so calling
/// this twice never duplicates the tile; the repo guard makes re-runs safe
/// too). The `manage_tables` gate lives inside the screen via `venue`.
void registerTablesModule() {
  if (!getIt.isRegistered<TablesPanelRepo>()) {
    getIt.registerLazySingleton<TablesPanelRepo>(
        () => TablesPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'tables',
    labelKey: 'tables',
    icon: Icons.table_chart_outlined,
    // `staffOpenOrders` is the shell's route back to the Orders tab. The
    // tables screen offers it when the user taps an OCCUPIED table, so the
    // owner can jump straight to the order that is holding that table.
    // It is read here, at push time, because the shell registers it after
    // the hub tiles are built.
    builder: (restaurantId, venue) => TablesScreen(
      restaurantId: restaurantId,
      venue: venue,
      onOpenOrders: staffOpenOrders,
    ),
  ));
}
