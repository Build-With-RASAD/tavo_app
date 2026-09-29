// Authed browsing flow: splash -> main nav -> home -> restaurants tab ->
// restaurant details -> full menu -> add item -> "Book your seat" -> order
// error surfaces -> pop back -> reservations tab (401 state) -> account tab.
//
// The seeded token is deliberately invalid (kInvalidToken), so:
//  * public endpoints (home, restaurants, menu) load real data, and
//  * protected endpoints (order, reservation/my, profile) fail closed —
//    POST /v1/api/order answers 400 "Customer name and phone are required
//    for guest orders" and GETs answer 401 "Invalid token".
// No reservation, order or profile mutation can happen in this test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tavo/feature/Profile/ui/screens/profile_screen.dart';
import 'package:tavo/feature/booking/ui/screens/bookings_screen.dart';
import 'package:tavo/feature/home/ui/screens/main_nav_screen.dart';
import 'package:tavo/feature/home/ui/widgets/restaurant_card.dart';
import 'package:tavo/feature/restaurant/ui/screens/restaurant_details_screen.dart';
import 'package:tavo/feature/restaurant/ui/screens/restaurant_menu_screen.dart';
import 'package:tavo/feature/restaurant/ui/screens/restaurants_screen.dart';
import 'package:tavo/feature/restaurant/ui/widgets/menu_item_card.dart';
import 'package:tavo/feature/splash/ui/screens/splash_screen.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'authed: home -> restaurants -> details -> menu -> add -> book -> '
    'error -> reservations -> account',
    (tester) async {
      await launchApp(tester, authenticated: true);

      // Splash routes a token holder straight to the main navigation.
      await pumpUntil(
        tester,
        find.byType(SplashScreen),
        timeout: const Duration(seconds: 10),
        reason: 'app boots into SplashScreen',
      );
      await pumpUntil(
        tester,
        find.byType(MainNavScreen),
        timeout: const Duration(seconds: 15),
        reason: 'splash routes a token holder to the main nav',
      );

      // Home tab loads public data (shimmer while loading). Cold-cache
      // /v1/api/home measured 15-25s, so this pump gets a 60s budget.
      await pumpUntil(
        tester,
        find.byType(RestaurantCard),
        timeout: const Duration(seconds: 60),
        reason: 'home tab shows restaurants',
      );

      // Restaurants tab. IndexedStack keeps non-selected tabs offstage, so
      // the nav label is the only onstage "Restaurants" text while on Home.
      await tester.tap(find.text('Restaurants'));
      await pumpUntil(
        tester,
        find.byType(RestaurantsScreen),
        timeout: const Duration(seconds: 5),
        reason: 'restaurants tab is selected',
      );
      await pumpUntil(
        tester,
        find.byType(RestaurantCard),
        reason: 'restaurants grid loaded',
      );

      // Open the first restaurant's details.
      await tester.tap(find.byType(RestaurantCard).first);
      await pumpUntil(
        tester,
        find.byType(RestaurantDetailsScreen),
        timeout: const Duration(seconds: 5),
        reason: 'restaurant details screen opens',
      );
      final viewAllLink = find.descendant(
        of: find.byType(RestaurantDetailsScreen),
        matching: find.text('View All'),
      );
      await pumpUntil(
        tester,
        viewAllLink,
        reason: 'details menu preview loaded',
      );

      // Full menu screen (pushed on top of details, sharing OrderCubit).
      // "View All" renders below the fold (y=1011 on the 440x956 viewport) —
      // without ensureVisible the tap dispatches off-screen and hits nothing.
      await tester.ensureVisible(viewAllLink);
      await settle(tester, 300);
      await tester.tap(viewAllLink);
      await pumpUntil(
        tester,
        find.byType(RestaurantMenuScreen),
        timeout: const Duration(seconds: 5),
        reason: 'menu screen opens',
      );
      final menuItem = find
          .descendant(
            of: find.byType(RestaurantMenuScreen),
            matching: find.byType(MenuItemCard),
          )
          .first;
      await pumpUntil(
        tester,
        menuItem,
        reason: 'menu items loaded',
      );

      // Add button = GestureDetector whose direct child is an SvgPicture
      // (the customize button wraps a Container; the remove button only
      // renders once qty > 0, and we start at 0). Scroll the card into
      // view first — same below-fold hazard as the "View All" link.
      await tester.ensureVisible(menuItem);
      await settle(tester, 300);
      await tester.tap(
        find.descendant(
          of: menuItem,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.child is SvgPicture,
          ),
        ),
      );
      await pumpUntil(
        tester,
        find.text('Book your seat'),
        reason: 'cart bottom bar appears after adding an item',
      );

      // Syncs the cart into OrderCubit and calls placeOrder() — with the
      // invalid token the backend answers 400 "Customer name and phone are
      // required for guest orders", surfaced by the details screen listener.
      await tester.tap(find.text('Book your seat'));
      await pumpUntil(
        tester,
        find.textContaining('Customer name and phone'),
        reason: 'order error surfaces in a SnackBar',
      );

      // Pop menu + details (custom header buttons are plain GestureDetectors,
      // not BackButton, so drive the navigator directly).
      Navigator.of(tester.element(find.byType(RestaurantMenuScreen))).pop();
      await pumpUntilGone(
        tester,
        find.byType(RestaurantMenuScreen),
        reason: 'menu route pops',
      );
      Navigator.of(tester.element(find.byType(RestaurantDetailsScreen))).pop();
      await pumpUntilGone(
        tester,
        find.byType(RestaurantDetailsScreen),
        reason: 'details route pops',
      );

      // Reservations tab: GET /v1/api/reservation/my answers 401 with the
      // invalid token -> error widget with Retry (loaded at nav startup).
      await tester.tap(find.text('Reservations'));
      await pumpUntil(
        tester,
        find.byType(BookingsScreen),
        timeout: const Duration(seconds: 5),
        reason: 'reservations tab is selected',
      );
      await pumpUntil(
        tester,
        find.descendant(
          of: find.byType(BookingsScreen),
          matching: find.text('Retry'),
        ),
        reason: 'bookings shows its 401 error state with Retry',
      );

      // Account tab: profile renders its sections even after the 401.
      await tester.tap(find.text('Account'));
      await pumpUntil(
        tester,
        find.byType(ProfileScreen),
        timeout: const Duration(seconds: 5),
        reason: 'account tab is selected',
      );
      await pumpUntil(
        tester,
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.text('Settings'),
        ),
        reason: 'profile screen renders its sections',
      );

      expect(tester.takeException(), isNull);
    },
  );
}
