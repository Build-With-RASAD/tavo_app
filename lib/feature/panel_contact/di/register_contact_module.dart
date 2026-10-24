// lib/feature/panel_contact/di/register_contact_module.dart
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_contact/data/repo/contact_panel_repo.dart';
import 'package:tavo/feature/panel_contact/ui/screens/panel_contact_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/restaurant_profile_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_contact/di/register_contact_module.dart';
///   registerContactModule();
///
/// Registers [ContactPanelRepo] and swaps the `contact` hub placeholder
/// for the real screen ([MoreHubRegistry.register] replaces by id, so
/// calling this twice never duplicates the tile; the repo guard makes
/// re-runs safe too).
void registerContactModule() {
  if (!getIt.isRegistered<ContactPanelRepo>()) {
    getIt.registerLazySingleton<ContactPanelRepo>(
        () => ContactPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'contact',
    labelKey: 'contact_qr',
    icon: Icons.qr_code_2_outlined,
    builder: (restaurantId, venue) => PanelContactScreen(
      restaurantId: restaurantId,
      venue: venue,
    ),
  ));

  // Identity, copy and the two images — the contact screen edits phone and
  // social links, this one edits what guests actually see.
  MoreHubRegistry.register(MoreHubEntry(
    id: 'profile',
    labelKey: 'restaurant_profile',
    icon: Iconsax.profile_circle,
    builder: (restaurantId, venue) =>
        RestaurantProfileScreen(restaurantId: restaurantId),
  ));
}
