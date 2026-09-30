// lib/feature/panel_customers/di/register_customers_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_customers/data/repo/customers_panel_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/customers_screen.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_customers/di/register_customers_module.dart';
///   registerCustomersModule();
///
/// Registers [CustomersPanelRepo] and swaps the `customers` hub placeholder
/// for the real screen ([MoreHubRegistry.register] replaces by id, so
/// calling this twice never duplicates the tile; the repo guard makes
/// re-runs safe too). Read-only domain — no role gating.
void registerCustomersModule() {
  if (!getIt.isRegistered<CustomersPanelRepo>()) {
    getIt.registerLazySingleton<CustomersPanelRepo>(
        () => CustomersPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'customers',
    labelKey: 'customers',
    icon: Icons.people_outlined,
    builder: (restaurantId, venue) =>
        CustomersScreen(restaurantId: restaurantId, venue: venue),
  ));
}
