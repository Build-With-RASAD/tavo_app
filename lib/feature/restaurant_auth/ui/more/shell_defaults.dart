// lib/feature/restaurant_auth/ui/more/shell_defaults.dart
import 'package:flutter/material.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/branches_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/contact_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/customers_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/menu_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/reviews_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/settings_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/staff_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/tables_screen.dart';

import 'more_hub_registry.dart';

/// The eight More-hub modules at their fixed paths, registered as DEFAULT
/// entries so the hub is complete from the shell rework onward. Each module
/// task replaces its entry (same `id`) from `register<Name>Module()`; the
/// placeholder screens stay as the fallback for pre-module builds.
void registerShellDefaults() {
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'menu',
    labelKey: 'menu',
    icon: Icons.restaurant_menu_outlined,
    builder: (restaurantId, venue) =>
        MenuScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'tables',
    labelKey: 'tables',
    icon: Icons.table_chart_outlined,
    // `staffOpenOrders` is the shell's route back to the Orders tab, read at
    // push time — see the note on the declaration.
    builder: (restaurantId, venue) => TablesScreen(
      restaurantId: restaurantId,
      venue: venue,
      onOpenOrders: staffOpenOrders,
    ),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'customers',
    labelKey: 'customers',
    icon: Icons.people_outline,
    builder: (restaurantId, venue) =>
        CustomersScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'staff',
    labelKey: 'staff',
    icon: Icons.badge_outlined,
    builder: (restaurantId, venue) =>
        StaffScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'branches',
    labelKey: 'branches',
    icon: Icons.storefront_outlined,
    builder: (restaurantId, venue) =>
        BranchesScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'reviews',
    labelKey: 'reviews',
    icon: Icons.star_border,
    builder: (restaurantId, venue) =>
        ReviewsScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'settings',
    labelKey: 'settings',
    icon: Icons.settings_outlined,
    builder: (restaurantId, venue) =>
        SettingsScreen(restaurantId: restaurantId, venue: venue),
  ));
  MoreHubRegistry.registerDefault(MoreHubEntry(
    id: 'contact',
    labelKey: 'contact_qr',
    icon: Icons.qr_code,
    builder: (restaurantId, venue) =>
        ContactScreen(restaurantId: restaurantId, venue: venue),
  ));
}
