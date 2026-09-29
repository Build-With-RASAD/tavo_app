# TDD Evidence — Restaurant (staff) login + reservations flow

Date: 2026-09-29
Feature: onboarding "مـتـابـعـة كـ مـطـعم" button → staff OTP login → venue reservations with status actions.

## Requirement

The restaurant button on the last onboarding page was a no-op (`_onSkip` only
re-navigated to the already-visible last page) and `tavo-app` had zero staff
code. It now opens a phone + OTP staff flow that lands on a venue screen where
staff can confirm / seat / complete / cancel reservations.

## Backend contracts (verified live against `root@46.202.134.87:4321`)

1. `POST /v1/api/auth/restaurant-login {countryCode, phone}` →

```json
{"success":true,"message":"OTP sent successfully","hasRestaurantAccess":true,
 "restaurants":[{"restaurantId":"6a9e23a52204c50612306408","name":"برغر لاب",
 "nameEn":"Burger Lab","nameAr":"برغر لاب","role":"owner",
 "permissions":["full_access"],"status":"active"}]}
```

2. `POST /v1/api/auth/verify-restaurant-otp {countryCode, phone, otp}`
   (dev OTP `1111`) → `token`, `restaurants[]`, `isRestaurantOwner`.
3. `GET /v1/api/reservation/restaurant/:id` (Bearer) →
   `{success, data: {reservations: [...], pagination}}` — 3 Burger Lab rows
   returned (`pending | seated | cancelled`), each with populated
   `userId: {name, phone}` (parsed into `BookingModel.guestName/guestPhone`).
4. Action routes: `PATCH /v1/api/reservation/:id/{confirm,seat,complete,cancel,no-show}`.
   Service transitions match the UI exactly:
   - `confirm` — pending → confirmed (only)
   - `seat` — confirmed → seated (only)
   - `complete` — confirmed | seated | finished_meal → completed
   - `cancel` — pending/confirmed rows only are offered by `nextActionsFor`

## RED

New tests written before implementation (all failed to compile / asserted):

| File | Coverage |
|---|---|
| `test/staff_restaurant_test.dart` | `StaffRestaurant` parse, missing-field defaults, `displayName`, `toJson` round-trip, `isManager` |
| `test/restaurant_auth_cubit_test.dart` | login → `OtpSent` + venues, 403 → error, verify → `Authenticated`, wrong OTP → error, resend, logout |
| `test/restaurant_home_cubit_test.dart` | load → `Loaded`, load failure → `Error`, confirm flips row, failed action keeps list + surfaces `actionError` |
| `test/booking_guest_test.dart` | guest from populated `userId`, `customer` fallback, empty default |
| `test/restaurant_flow_widget_test.dart` | login → OTP screen, OTP → home with guest row, Confirm flips pending → confirmed |
| `test/onboarding_screen_regression_test.dart` (modified) | restaurant button now asserts navigation to `RestaurantLoginScreen` |

RED evidence: `flutter test` on the three new unit files → `Some tests failed`
(8 failures: missing files + unimplemented behavior).

## GREEN

- `lib/feature/auth/ui/data/models/staff_restaurant.dart` (new)
- `AuthResponse` += `hasRestaurantAccess`, `restaurants`, `isRestaurantOwner`
- `BookingModel` += `guestName`, `guestPhone` (backward-compatible defaults)
- `lib/feature/restaurant_auth/` (new feature): `RestaurantAuthRepo`,
  `RestaurantAuthCubit` + states, `RestaurantHomeCubit` + states,
  `RestaurantLoginScreen`, `RestaurantOtpScreen`, `RestaurantHomeScreen`
- `ApiConstants` += 4 staff endpoints; `CacheHelper` += `staffMode` + cached
  venues JSON (cleared by `clearUserData`); DI registrations in `service_locator.dart`
- Onboarding `:293` → `_navigateToRestaurantLogin`; splash routes
  `isLoggedIn && isStaffMode` → `RestaurantHomeScreen` (corrupt cache → `[]`,
  no crash)
- i18n: 8 new keys in `en.json` + `ar.json` (312/312 key parity preserved;
  formatting-preserving append — only the new lines diff)
- **Bug found & fixed en route**: `pin_code_fields` `autoDisposeControllers`
  defaults to true, double-disposing the screen-owned OTP controller
  ("A TextEditingController was used after being disposed" on navigation).
  Fixed in the staff OTP screen; the customer screen now sets it explicitly too.

## GREEN verification (this session)

- `flutter analyze` → **0 errors, 0 warnings** (24 pre-existing info lints)
- `flutter test` → **47/47 passed** (26 pre-existing + 21 new/updated)
- Live curl round-trip (login → OTP → token → venue reservations) succeeded
  against the production server; payloads match the parsers used in tests.

## Non-scope

Orders management, menu editing, analytics, staff management, real SMS
(server runs `NODE_ENV=development`, `DEV_OTP=1111`; SMS provider is unconfigured).
