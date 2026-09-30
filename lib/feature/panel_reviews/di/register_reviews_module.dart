// lib/feature/panel_reviews/di/register_reviews_module.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_reviews/data/repo/reviews_panel_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/reviews_screen.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_reviews/di/register_reviews_module.dart';
///   registerReviewsModule();
///
/// Registers [ReviewsPanelRepo] and swaps the `reviews` hub placeholder for
/// the real screen ([MoreHubRegistry.register] replaces by id, so calling
/// this twice never duplicates the tile; the repo guard makes re-runs safe
/// too). The `manage_reviews` gate lives inside the screen via `venue`.
void registerReviewsModule() {
  if (!getIt.isRegistered<ReviewsPanelRepo>()) {
    getIt.registerLazySingleton<ReviewsPanelRepo>(
        () => ReviewsPanelRepo(api: getIt<ApiService>()));
  }
  MoreHubRegistry.register(MoreHubEntry(
    id: 'reviews',
    labelKey: 'reviews',
    icon: Icons.reviews_outlined,
    builder: (restaurantId, venue) =>
        ReviewsScreen(restaurantId: restaurantId, venue: venue),
  ));
}
