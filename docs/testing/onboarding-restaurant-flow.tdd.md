# TDD evidence: onboarding crashes + restaurant-flow port (tavo-app)

## RED (failing first)
- `test/onboarding_screen_regression_test.dart` (new, 3 tests) failed before the fix:
  - skip tap → `ProviderNotFoundException: Provider<OnboardingCubit>` (exact reported crash)
  - "متابعه ك مطعم" tap → same exception
  - last-page icon audit → `MySvg(image: account (2))` has no file at `assets/icons/account (2).svg`
- Moved suite failed in tavo-app before porting deps:
  - `short_id_test` → compile error (missing `lib/core/helpers/utils/short_id.dart`)
  - `menu_booking_button_test` → `placeOrderCalls` 0, expected 1 (dead `onPressed: () {}`)

## GREEN (minimal fix, no test weakened)
- `lib/feature/onboarding/ui/screens/onboarding_screen.dart`:
  `image: 'account (2)'` → `'account'` (existing asset);
  `_onSkip()` → `_onSkip(OnboardingCubit cubit)` threaded from builder scope at both
  call sites (State context sits above the in-`build()` BlocProvider).
- Ported from tavo_resturant working tree: `short_id.dart` (new),
  bookings_screen `_loadingSheetOpen` guard + `shortId()` use,
  restaurant_details_screen `shortId()` use, restaurant_menu_screen
  "Book your seat" cart-sync block, booking_bottom_sheet no-tables feedback,
  `splash_logo.png`, `PrivacyInfo.xcprivacy` + pbxproj wiring + Podfile clamp,
  `userAgentPackageName` → `com.rasad.tavo` (3 files), `PRODUCTION.md` docs.
- Deleted tavo-app's broken stock `test/widget_test.dart` (counter UI doesn't exist;
  `production_config_test` docstring states it replaces it — same as restaurant did).

## Verification (this session)
- `flutter test`: **26/26 passed** (3 onboarding + 4 short_id + 1 menu + 4 bookings +
  9 production-config + 5 guest_selector).
- `flutter analyze`: 0 errors (24 pre-existing info/warning lints).
- tavo_resturant deleted per explicit user instruction (no backup, per user choice).
  Not ported (restaurant-identity): bundle IDs, display names, branded icons/splash,
  `key.properties` + `tavo-upload-key.jks`, web/index.html branding, `back_arrow`
  (referenced only by unused `PrimaryBackIcon`).
