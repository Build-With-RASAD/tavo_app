# Production readiness — Tavo (`tavo-app`)

Single surviving app of the `tavo` workspace. The `tavo_resturant` clone was
retired per `.opencode/plan-restaurant-flow.md` (its original doc is preserved
at `.opencode/PRODUCTION.tavo_resturant.retired.md`).

- Repo: <https://github.com/ABWABDIGITAL/tavo_app.git>
- Target backend: **`http://46.202.134.87:4321`** — identical to
  `lib/core/network/api_constants.dart`, locked by
  `test/production_config_test.dart`.

## App identity

| Item | Value |
|------|-------|
| Android `applicationId` / `namespace` | `com.rasad.tavo` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` (tests: `.RunnerTests`) | `com.rasad.tavo` |
| Home-screen display name (Android label / iOS `CFBundleDisplayName`) | `Tavo` |
| Dart package name | `tavo` |

> The retired clone used `com.tavo.restaurant.rasad` / "Tavo Restaurant".
> This app intentionally keeps the original tavo-app identity — restaurant
> branding was explicitly out of migration scope.

## API

- Base URL is plain **HTTP** (`http://46.202.134.87:4321`).
- **iOS** (`ios/Runner/Info.plist`, added 2026-09-29):
  - `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` so the app can
    reach the HTTP backend at all (previously claimed in this doc but not
    present in the plist).
  - `LSApplicationQueriesSchemes` = `tel`, `mailto`, `sms`, `http`, `https`
    for `url_launcher` `canLaunchUrl` checks (also previously claimed but
    missing).
- **Android — deferred this pass** (no Android build/run; user instruction).
  Main manifest currently has `INTERNET`, `CAMERA`,
  `READ/WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`.
  **Known gaps:** no `android:usesCleartextTraffic="true"` (Android 9+ blocks
  this HTTP API by default), no `ACCESS_NETWORK_STATE`, no `<queries>` entries
  for tel/mailto/http(s) (Android 11+ package-visibility).

> **Before store submission:** put the backend behind HTTPS and remove the
> ATS/cleartext exceptions above. HTTP sends tokens and personal data
> unencrypted.

## Permissions & privacy manifests

- iOS: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`,
  `ITSAppUsesNonExemptEncryption = false`, and `ios/Runner/PrivacyInfo.xcprivacy`
  wired into the Runner target (Resources build phase).
- Android: as listed above; see gaps.

## iOS deployment target (Apple requires ≥ 15)

- `ios/Podfile`: `platform :ios, '15.0'` + `post_install` clamp raising any
  pod target below 15.0 up to 15.0.
- `Runner.xcodeproj`: all three `IPHONEOS_DEPLOYMENT_TARGET` entries raised
  13.0 → 15.0.

## Splash & launcher icons

- Launcher icons: `flutter_launcher_icons` from `assets/icons/logo_icon.png`
  (Android adaptive icon on white; iOS icon set regenerated and committed in
  `f2c2503`).
- Native launch screen: **Flutter default (white)** — this app has **no**
  `flutter_native_splash` configuration. The branded splash is the in-app
  animated `SplashScreen`.
- `assets/images/splash_logo.png` is present but unreferenced (orphan asset).

## Dependency hygiene

- Actually imported: `flutter_map` (3 files), `url_launcher` (2 files).
- Declared but **never imported**: `google_sign_in`, `sign_in_with_apple`,
  `google_maps_flutter`, `pay`. They still compile into the iOS build (Xcode
  warns that `google_maps_flutter_ios`, `pay_ios`, `sign_in_with_apple` do not
  support Swift Package Manager yet — "will become an error in a future
  version of Flutter"). Removing them would shrink the binary and clear the
  warning.

## Verification performed (2026-09-29)

- `flutter pub get` — OK (Flutter 3.44.5).
- `flutter analyze` — **0 errors**; 24 pre-existing warnings/infos
  (unused_element/unused_import baseline, unchanged by this pass).
- `flutter test` — **47/47 passed** (includes tests added by the
  concurrent staff-auth work).
- iOS simulator build + `flutter test integration_test` on iPhone 17 Pro Max
  (iOS 26.3) — **2/2 E2E flows passed**, see E2E section below.

<!-- E2E_RESULTS_START -->
## E2E results (2026-09-29, final run)

- Suite: `flutter test integration_test -d <simulator>` → **All tests
  passed — 2/2** (exit 0):
  - `first_launch_flow_test` — splash → onboarding → login validation →
    OTP request → wrong-code rejected (~24s).
  - `authed_browsing_flow_test` — home → restaurants → details → full
    menu → add item → Book your seat → guest-order 400 snackbar →
    reservations (401 state) → account (~1m34s).
- Critical fixes this pass required to go green:
  1. **iOS ATS**: `NSAllowsArbitraryLoads=true` +
     `LSApplicationQueriesSchemes` in `Info.plist` (backend is plain HTTP
     on port 4321).
  2. `integration_test` dev dependency added to `pubspec.yaml`.
  3. **OTP double-dispose**: `PinCodeTextField` now sets
     `autoDisposeControllers: false` (pin_code_fields 8.0.1 disposes the
     OtpScreen-owned controller before the screen's own `dispose()`).
  4. **Missing assets**: `trash.svg` (authored), `bell.svg`,
     `back_arrow.svg` (sourced) — build failed without them.
  5. **Harness hardening**: `ensureVisible` before tapping below-fold
     targets ("View All" renders at y≈1011 on the 956px viewport); `.first`
     finders throw `StateError` while empty, so `pumpUntil`/`pumpUntilGone`
     map that to "not yet"; data pumps budget 60s.
- Run note: warm `/v1/api/home`, `/v1/api/restaurant`, details + menu
  endpoints before launching the suite (see backend note in Known issues).
<!-- E2E_RESULTS_END -->

## E2E suite design (`integration_test/`)

- Files: `e2e_helpers.dart`, `first_launch_flow_test.dart`,
  `authed_browsing_flow_test.dart` (Flutter `integration_test` on the iOS
  simulator; the repo-wide Cypress mandate applies to web targets).
- Harness rules: `getIt.reset()` before every `app.main()`; prefs seeded
  before launch (`locale: 'en'`; invalid token for the authed file); never
  `pumpAndSettle` (shimmer / promo ticker / OTP countdown never idle) —
  real-clock `pumpUntil` polling instead.
- Backend safety: the authed flow seeds `e2e-invalid-token`, so protected
  endpoints fail closed (401 / guest-order 400) and **no reservation, order
  or profile state is ever created**; the login flow only triggers an OTP
  request for a sandbox number and one wrong-OTP verification.
- Known coverage gap: fully authenticated flows (real booking / order
  placement / profile edits) require a real OTP and are not automated.

## Known issues & remaining manual steps

1. **iOS signing**: `DEVELOPMENT_TEAM` is unset — set it in Xcode before
   archiving/distribution.
2. **HTTPS migration** (top hardening step) — then remove
   `NSAllowsArbitraryLoads`.
3. **Android deferred**: no build/signing verification this pass; no
   `key.properties`/keystore exists in this repo. The retired clone's
   keystore (if it was ever created) was git-ignored — recover it from that
   app's archive if Play updates under the old signing key are ever needed;
   the archive's location was not found.
4. **Onboarding flag never set**: `setOnboardingCompleted()` is never called,
   so a user without a token always lands on onboarding (including after
   logout).
5. **Restaurant onboarding CTA**: was a no-op; the concurrent staff-auth
   work has since wired it to a new `RestaurantLoginScreen` (verified in
   source, not yet E2E-covered).
6. **Missing-icon fixes landed 2026-09-29**: `assets/icons/trash.svg`,
   `bell.svg`, `back_arrow.svg` did not exist in the repo at all (profile
   delete-account row and notifications empty-state rendered broken images).
   `trash.svg` was newly authored; `bell.svg`/`back_arrow.svg` reuse
   `notification.svg`/`arrow_right.svg`.
7. **Concurrent uncommitted work detected** during the E2E pass (staff-login
   feature: `staff_restaurant.dart`, `restaurant_auth/*`, edited
   `auth_response.dart`/`signup_screen.dart`, translation updates) — not
   authored by this E2E work; confirm ownership before committing.
8. **Backend `/v1/api/home` latency**: measured 15–25s on cold cache
   (~0.4s warm), with erratic TCP connect times (1.5–7.6s) from this
   network. User-visible first-load impact worth investigating
   server-side; the E2E suite warms the endpoints and budgets 60s.
