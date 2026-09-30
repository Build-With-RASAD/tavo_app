# Restaurant Management System — Wave 1 TDD & verification evidence

Append-only. Every task appends its RED (captured failing output) and GREEN
(passing output) here; the controller commits it with the task's code.
Baselines at Wave 1 start: `flutter test` 97/97 · `flutter analyze` exactly
24 issues (0 new) · backend `npm test -- tests/unit` 32 suites / 343 tests.

## Task 1 — i18n script + panel envelope helper

RED (backend): `npm test -- tests/unit/i18n-add-script.test.js` → 6 failed
(script missing) · GREEN → 6 passed.
RED (flutter): `flutter test test/panel_envelope_test.dart` → import of
`panel_envelope.dart` unresolved · GREEN → 4 passed.

## Task 2 — legacy mutation auth (branches / menu-item / table)

RED: `npm test -- tests/unit/legacy-mutation-auth.test.js` → 7 failed, 6 passed.
Failing 401/403 assertions (mutations ran unauthenticated):
- POST /branches no token: expected 401, got 400; staff: expected 403, got 400.
- POST /menu-item no token: expected 401, got 404; staff: expected 403, got 404.
- POST /table no token: expected 401, got 400.
- DELETE /table/:id staff: expected 403, got 200 (staff could mutate).
(Setup note: brief's `assign` helper omitted required `assignedBy`; fixed by
passing `assignedBy: superadminUser._id`. All 13 test assertions otherwise verbatim
except DELETE-table final state — see concerns.)
GREEN: 13 passed, 0 failed.
Deviations from brief snippet (both required for GREEN, routes files only):
- menu-item POST/PUT: added `validateRequest` after the validators (brief snippet
  omits it; the controller never checks validationResult, so without it the owner
  request falls through to the service and 404s on the fake category instead of
  the specified 400 + errors array).
- DELETE /table/:id test asserts the service's existing soft-delete toggle
  (active→inactive, 200) instead of hard-delete `toBeNull()`; changing delete
  semantics would mean editing `src/services/table.services.js`, out of scope.

## Task 3 — fix requirePermission + wire all 39 panel routes

RED (middleware): `npm test -- tests/unit/require-permission.test.js` →
3 failed, 4 passed. Failing: query fallback (400, no lookup — `req.query`
never read), owner bypass (`You don't have required permissions:
manage_staff`), superadmin short-circuit (400 — no `req.query` fallback, so
it hit the missing-id branch before any role check). Varargs-grant,
deny-403, full_access, and 400 tests already passed via the scalar fallback
(mocked assignment has no `hasPermission` method).
GREEN (middleware): 7 passed, 0 failed.
RED (route matrix): `npm test -- tests/unit/panel-route-permissions.test.js` →
2 failed, 4 passed. Offender list = all 38 permissioned routes (each returned
non-403 — controllers ran unwired, mostly 404s); `view_orders` write also
non-403. (Setup notes: pinned restaurant `_id: RID` so `?restaurantId=RID`
URLs resolve; added required `assignedBy` to the `assign` helper — same class
of fix as Task 2; prefixed matrix targets with `/v1/api/restaurant-owner`
— the brief snippet requested bare paths, which Express 404s outside the
mount. No assertion weakened.)
GREEN (route matrix): 6 passed, 0 failed, offender list empty.
FULL: `npm test -- tests/unit` → 36 suites / 375 tests, all green.

## Task 4 — floor-plan backend (position + PUT /floor-plan)

RED: `npm test -- tests/unit/floor-plan.test.js` →
suite failed to run: `Cannot find module '../../src/routes/floor-plan.route.js'
from 'tests/unit/floor-plan.test.js'` (0 tests — the missing route module is
the RED signal, as specified).
GREEN: 9 passed, 0 failed.
Deviations from brief snippet (both required for GREEN, test file only):
- `Restaurant.create` pins `_id: RID` so `?restaurantId=RID` URLs resolve to
  the venue (repo convention from panel-route-permissions.test.js; without it
  every authed call 403s since no assignment exists for the random id).
- `assign` helper adds required `assignedBy: u._id` (schema marks it
  required; without it StaffAssignment.create throws a validation error).
  No assertion weakened.
FULL: `npm test -- tests/unit` → 38 suites / 397 tests, all green.
(Brief expected 37/384 from a 36/375 baseline; sibling wave-1 work landed
since — e.g. waitlist-panel — so the pre-task baseline had already drifted.
This task adds exactly 1 suite / 9 tests, zero regressions.)

## Task 5 — waitlist panel backend (list + notify/confirm/no-show/cancel)

RED: `npm test -- tests/unit/waitlist-panel.test.js` →
suite failed to run: `Cannot find module '../../src/routes/waitlist-panel.route.js'
from 'tests/unit/waitlist-panel.test.js'` (0 tests — the missing route module is
the RED signal, as specified).
GREEN: 12 passed, 0 failed.
Transition semantics verified against `src/services/admin-waitlist.services.js`
before implementing — exact match (notify `waiting→notified` + `notifiedAt` +
`notifiedBy:"admin"`; confirm/no-show/cancel from `waiting|notified`; illegal
transition → 400 `Cannot mark this entry as …` echoing current status).
Deviations from brief snippet (all in the test file only, all required for
GREEN — same class of fix as Tasks 2/4; no assertion weakened, still 12 tests):
- `Restaurant.create` pins main venue `_id: RID` (repo convention from
  panel-route-permissions.test.js; without it every `?restaurantId=RID` call
  403s since no assignment exists for the random id).
- `assign` helper adds required `assignedBy: u._id` (schema marks it required;
  without it StaffAssignment.create throws a validation error).
- New `manager` user (`staff`, `["view_reservations","manage_reservations"]`)
  drives the mutation success paths; the brief snippet reuses the
  `view_reservations`-only `viewer` there, which the brief's own router
  (`requirePermission("manage_reservations")` on all four PATCH routes) would
  403 — contradicting the expected 200s and duplicating the final 403-denial
  test. `viewer` still drives all GETs + the 403 mutation-denial test; `owner`
  still drives the cross-restaurant 404 test. `markedBy` assertion now targets
  the manager.
- `makeEntry` generates a unique phone per entry (partial unique index on
  `(restaurantId, customer.phone)` for `waiting`/`notified`; the brief's fixed
  phone would duplicate-key on the second same-venue entry).
FULL: `npm test -- tests/unit` → 38 suites / 397 tests, all green.
(First full run showed 1 flake: `user.model.test.js` "duplicate phone number"
failed once, then passed in isolation and on full re-run — unique-index race,
untouched by this task. Pre-task baseline 37/385; this task adds exactly
1 suite / 12 tests, zero regressions.)

## Task 12 — Panel menu UI (categories + items CRUD, role-gated)
RED: `flutter test test/panel_menu_test.dart` → compile errors
`Target of URI doesn't exist: 'package:tavo/feature/panel_menu/...'` (all 4
lib imports), as specified.
GREEN: 8 passed, 0 failed.
FULL: `flutter test` → 114 passed, 0 failed (baseline 101 + this task's 8 +
concurrent tasks' additions; zero regressions). `flutter analyze` → exactly
24 issues, 0 in `panel_menu` (baseline 24, unchanged).
Deviations from brief snippet (all required for GREEN; no assertion weakened,
still 8 tests):
- Fake overrides carry the real optional named `restaurantId`
(`toggleStatus`/`deleteItem`/`createCategory`) so `@override` type-checks
(brief Step 5 anticipates this fix).
- Test file adds the two imports the snippet omits but uses:
`core/widgets/state/async_state_view.dart` (`ListSkeleton`) and
`feature/auth/ui/data/models/staff_restaurant.dart` (`StaffRestaurant`).
- `_pumpMenu` pumps until the skeleton is in the tree: EasyLocalization
finishes loading translations asynchronously and a bare `pumpAndSettle` can
exit before the child subtree is built (documented in
`test/helpers/app_shell.dart`), so the immediate loading assertion needs it.
- Price renders as its own `Text` (`Row`: label + value) so
`find.text('32')` matches; a single `"Price: 32"` Text would not.
- Repo error-parser import is the on-disk path
`core/network/api_error_parser.dart` (brief Step 5 names
`core/utils/error_parser.dart`, which does not exist); single-object payloads
go through `Map<String, dynamic>.from` like `RestaurantPanelRepo`.
- `copyWith` gains `clearCategory` so `setCategory(null)` can clear the
client-side category filter (bare `??` cannot distinguish null-as-clear).
- `PanelMenuCubit` also implements the brief-interface `deleteCategory`
(Step 6 code omits it); `register_menu_module.dart` drops the brief's unused
`get_it`/`staff_restaurant` imports (would be new analyze issues) and guards
re-registration with `isRegistered` (hub `register` already replaces by id).

## Task 11 — shell rework: 5 tabs + More hub registry

RED: `flutter test test/more_hub_test.dart test/staff_shell_widget_test.dart` →
both files fail to load: `more_hub_registry.dart` / `more_hub_screen.dart`
"No such file or directory" + `Undefined name 'MoreHubScreen' /
'waitlistBadgeCount'` (implementation not written yet — expected RED).
GREEN (targeted): `flutter test test/more_hub_test.dart
test/staff_shell_widget_test.dart test/restaurant_flow_widget_test.dart` →
12 passed, 0 failed (hub 3, shell 6 = 4 pre-existing byte-identical + 2 new,
flow 3 unchanged).
GREEN (full): `flutter test` → 114 passed, 0 failed (101 baseline + 5 new here
+ 8 from parallel Wave A tasks, e.g. Task 12 menu; grows only, never shrinks).
`flutter analyze` → exactly 24 issues, 0 in new/modified files
(`restaurant_auth/ui/more/*`, `waitlist_tab.dart`, the 8
`restaurant_panel/ui/screens/*_screen.dart` placeholders, `staff_shell_screen.dart`,
`more_hub_test.dart`, `staff_shell_widget_test.dart` all clean).
i18n (via script, not hand-edited): `added: more, waitlist, waitlist_empty,
hub_empty, customers, staff, branches, reviews, contact_qr` in both en + ar.
Deviations from brief test snippets (new tests only; the 4 pre-existing shell
tests are byte-identical — only 2 imports added + 2 tests appended):
- `more_hub_test.dart` empty-state test adds `pumpAndSettle` after `pumpWidget`
(same EasyLocalization async-load reason documented in `app_shell.dart`).
- `more_hub_test.dart` defaults test sets a tall surface
(`physicalSize 800x2400`, reset in tearDown): the default 800x600 surface fits
~2 hub rows under ScreenUtil scaling, so `GridView.builder` never builds the
lower tiles and verbatim `find.text('Branches'…)` fails. Assertion loop itself
verbatim.
- `more_hub_test.dart` module-wins half re-pumps the hub after
`MoreHubRegistry.register(...)`: the registry is a plain global store (no
notifier, per brief), so the built hub only picks up the replacement on
rebuild — production registers at DI time before first build, so semantics
unchanged.
- Shell badge test scopes the finder to the NavigationBar
(`find.descendant(of: find.byType(NavigationBar), …)`): the dashboard renders
a bare `'3'` (fake repo pending orders), which collides with a global
`find.text('3')` once the badge value is also 3. Still `findsOneWidget` /
`findsNothing` — same gate, no weakening.
No plan-file contradiction: plan Task 11 section matches the brief verbatim.
