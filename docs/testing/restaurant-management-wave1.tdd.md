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

## Task 9 — public QR menu page (GET /menu/:slug)

RED: `npm test -- tests/unit/public-menu.test.js` → suite failed to run:
`Cannot find module '../../src/routes/public-menu.route.js'` (implementation
not written yet — expected RED).
GREEN (targeted): `npm test -- tests/unit/public-menu.test.js` → 6 passed,
0 failed (HTML content-type + cache headers + X-Cache MISS/HIT, ar default /
en switch with lang-keyed cache, XSS escaping `<script>` → `&lt;script&gt;`
in both langs, inactive items hidden, styled 404 HTML, index.js mount check).
No deviations: test, service, controller, route, and mount all verbatim from
the brief. XSS load-bearing gate holds — zero `<script>` tags in templates by
construction, every interpolated string through `escapeHtml` (`&<>"'`).

Adopter RED reconstruction (Wave B): route/service moved to /tmp → import-failure RED (0 ran); restored → 6/6 GREEN. XSS `<script>` payload asserts escaped (`&lt;script&gt;`) in both langs.

## Task 6 — customers CRM backend (read-only aggregation)

RED: pre-existing state — `tests/unit/customers-panel.test.js` and all four
`src/**/customers-panel.*` files were already present from a prior attempt of
this task (test matches the brief with two load-bearing fixes: `assignedBy`
on `StaffAssignment.create` — schema requires it — and `_id: RID` on the
seeded restaurant so `?restaurantId=${RID}` resolves). Import-failure RED was
therefore already satisfied before this run; no files were created or edited
in this pass (verification-only).
GREEN (targeted): `npm test -- tests/unit/customers-panel.test.js` →
12 passed, 0 failed (401 no-token, 403 view_reservations-only denied,
nested envelope `{data, pagination}` with item shape + guest phone-key
grouping + member userId-key, isolation from other restaurant, search by
name case-insensitive / phone / metacharacters-as-literals (`.*(…` and `*`
→ 200 with zero hits, no hang), pagination boundary total:2/pages:2,
400 on limit=999, detail by userId key with orders+reservations, detail by
guest phone case-insensitive, 404 unknown key).
No deviations: validator, service (aggregation with `KEY_EXPR` userId-else-
lowercased-phone, literal `includes` search, `$expr`/`$toLower` detail
lookup — never a regex built from `:key`), controller, and route all match
the brief. `escapeRegex` stays exported for server-side literal matching.
Review Focus gates hold: restaurantId matched first in every aggregation (3),
search is literal-only (4).
Baseline: `npm test -- tests/unit` → 43 suites, 430 tests: 424 passed,
6 failed — all 6 in sibling in-progress suites (`branches-panel`: route
module missing, still RED; `contact-panel` Task 8: 403s + serialization
mismatches). `customers-panel` 12/12 green; no regressions in any suite
this task owns or touches. Mount NOT applied (controller owns
`restaurant-owner.routes.js`): snippet reported below.
Mount snippet:
```js
// restaurant-owner.routes.js — one line, before `export default router;`
import customersPanelRoutes from "./customers-panel.route.js";
router.use(customersPanelRoutes);
```

## Task 13 — reservations migration (panel API) — implementer evidence

RED (`flutter test test/panel_reservations_test.dart`, before Step 4):
- `restaurant_home_cubit.dart:25` — `getRestaurantReservations` isn't defined
  for `RestaurantPanelRepo`.
- `restaurant_home_cubit.dart:44` — `updateReservationStatus` isn't defined
  for `RestaurantPanelRepo`.
- `restaurant_panel_repo.dart:121` — brief-verbatim `final (rows, _) =
  panelUnwrapList(payload)` does not compile against the Task 1 helper's
  NAMED record `({List<dynamic> items, ...})`; adapted to
  `result.items` (same rows, same mapping).
- `service_locator.dart:102` — `RestaurantAuthRepo` no longer assignable to
  the cubit's `RestaurantPanelRepo` param (controller-owned Diff A).

GREEN (after Steps 3–4): 4/4 cubit unit tests pass —
`load hits the panel endpoint with limit=100 and emits rows`,
`load failure emits the error state`,
`updateStatus confirm swaps the row through the panel action`,
`updateStatus failure keeps the list and surfaces actionError`.
Proven via a temporary scaffold copy of the 4 unit tests (no
`reservations_tab` import): `00:00 +4: All tests passed!` — scaffold deleted
after the run. The 5th test in `panel_reservations_test.dart` (widget test)
cannot load until the controller applies Diff A: `reservations_tab.dart`
transitively imports `service_locator.dart`, which fails compilation at
line 102 by design of this migration.
`flutter analyze`: 28 issues = baseline 24 + 4 transitional compile errors
in controller-owned files (service_locator, restaurant_flow_widget_test,
restaurant_home_cubit_test, staff_shell_widget_test); 0 issues in the three
task files (one `unintended_html_in_doc_comment` info on the new repo doc
comment fixed with backticks around `<action>`).

Reported diffs (controller applies — implementer touched neither file):
- Diff A (service_locator.dart:100-103): factoryParam switches
  `getIt<RestaurantAuthRepo>()` → `getIt<RestaurantPanelRepo>()`.
- Diff B (restaurant_flow_widget_test.dart): `FakePanelRepo` gains
  `homeReservations`-backed `getReservations`/`updateReservationAction`
  overrides (brief snippet); the `registerFactoryParam<RestaurantHomeCubit>`
  points at `panelRepo`; the two `repo.reservations = [_booking()];` seeds
  (lines ~201, ~251) move to the panel fake.
- Diff C (staff_shell_widget_test.dart): same two overrides on its
  `FakePanelRepo` backed by its existing `reservations` fixture; the
  `registerFactoryParam<RestaurantHomeCubit>` line changes
  `RestaurantHomeCubit(repo, ...)` → `RestaurantHomeCubit(panelRepo, ...)`.
- Diff D (NOT in brief — required): `restaurant_home_cubit_test.dart`
  `FakeHomeRepo extends RestaurantAuthRepo` no longer satisfies the cubit's
  constructor; it must extend `RestaurantPanelRepo` with the new method
  names (`getReservations(restaurantId, {limit})`,
  `updateReservationAction(restaurantId:, id:, action:, reason:)`), keeping
  all 5 existing assertions (`loadCalls`, error, confirm-flips-row,
  failed-action-keeps-list, close-during-load).

## Task 7 — branches panel backend (CRUD + soft delete) — orphan-adopted
RED (orphan, confirmed): `npm test -- tests/unit/branches-panel.test.js` → suite failed to run (`Cannot find module '../../src/routes/branches-panel.route.js'`, 0 tests ran).
GREEN: 11 passed, 11 total (brief Step 6 says "12" but the Step 1 block has 11 `it`s — brief count defect, 11 is true).
Setup corrections (test-only, no assertion changed): `assignedBy` on assign helper; main restaurant `_id: RID`. Route addition: 3-line `stripBodyRestaurantId` middleware (venue middleware resolves body-first).
FULL at adoption: 43 suites / 441 tests, all green.

## Task 8 — contact backend (model + GET/PUT /contact) — orphan-adopted
RED captured: `npm test -- tests/unit/contact-panel.test.js` → 6 failed, 2 passed (TEST-side bug: hardcoded `?restaurantId=RID` vs random restaurant ObjectId → 403s; implementation already brief-verbatim).
GREEN after 1-line test-setup fix (`_id: RID` in Restaurant.create): 8 passed. No assertion added, removed, or weakened.

## Task 10 — menu image upload backend — orphan-verified
RED reconstructed: implementation files (route/service/controller) moved to /tmp → suite failed to run (`Cannot find module`, 0 total); restored → GREEN 7 passed, 7 total.
FULL at adoption: 43 suites / 441 tests, all green.

## Task 17 — waitlist UI (queue, filters, transitions, shell badge feed)
RED captured: `flutter test test/panel_waitlist_test.dart` → compile errors
(`panel_waitlist` package doesn't exist; Task 11 placeholder).
GREEN: 8 passed, 8 total. FULL: 152/152 green (119 baseline + 8 task-17 +
25 from concurrent sibling tasks). Analyze: 26 issues = 24 baseline + 2
from concurrent siblings (panel_settings prefer_const, panel_tables curly
braces); 0 from task-17 files.
Brief deviations (all test-side or compile-required, no assertion weakened):
- Added missing `async_state_view.dart` import (ListSkeleton used unimported).
- Fake gains 10ms Timer latency in getWaitlist/transition (instant fake
skips the skeleton/spinner frames; real repo is a network call) + one
extra `pump()` before the skeleton expect (frame 1 is EasyLocalization).
- `failure` set AFTER `load()` in the cubit failure test (one-shot fake
would fail the load instead; mirrors panel_reservations_test.dart).
- `e2` gets `ticket: 'A2'` (both entries default to 'A1', ambiguous finder).
- 'Notified'/'Cancelled' expects scoped to `wait_<id>` card (filter chips
render the same labels).
- Repo uses named record destructure `(items: rows, pagination: …)` (brief
positional form doesn't compile against panel_envelope.dart; menu pattern).
- `register_waitlist_module.dart` drops the unused `get_it` import
(`getIt` comes from service_locator; menu pattern); state file drops the
model re-export (caused 3 cascading unnecessary_import infos).
- `WaitlistTab` renders the Task 11 empty visual when `WaitlistPanelRepo`
is not registered (shell IndexedStack mounts every tab; shell suites predate
the module registration, which the controller wires via the one-liner).
Badge contract: `waitlistBadgeCount.value` set on every successful load
(+ after successful transitions); covered by shell badge test (green).
i18n: 12 keys × en/ar via script (verified present; `no_show` en is now
'No-show'). Controller wiring (NOT applied — service_locator untouched):
`import 'package:tavo/feature/panel_waitlist/di/register_waitlist_module.dart';`
+ `registerWaitlistModule();`

## Task 15 — Staff UI (list, add/edit, permissions, suspend/activate/delete)
RED: `flutter test test/panel_staff_test.dart` → compile error (`panel_staff` package doesn't exist: staff_models.dart / staff_panel_repo.dart / staff_panel_cubit.dart missing).
GREEN: 8 passed (`flutter test test/panel_staff_test.dart` → `00:01 +8: All tests passed!`).
Fixes vs brief snippet (no assertion changed): added the missing `async_state_view.dart` import (`ListSkeleton`); `_pumpStaff` gains the `pumpUntil`-skeleton amendment (same EasyLocalization timing rationale as panel_menu_test); sheets use `Material` instead of a decorated `Container` so (Checkbox)`ListTile` ink has a proper ancestor (debug assertion otherwise).
Suites touched all green: panel_staff 8/8, more_hub 3/3, panel_menu 8/8, panel_models 7/7, panel_envelope 4/4, panel_reservations 5/5, panel_settings 6/6.
Analyze: 26 issues total, 0 in task-15 files (the +2 over the 24 baseline sit in `panel_settings_screen.dart` and `tables_panel_repo.dart` — concurrent sibling tasks).
Full suite: 11–13 failures in `staff_shell_widget_test` / `panel_waitlist_test` / `restaurant_flow_widget_test`, all `GetIt: WaitlistPanelRepo is not registered` (sibling waitlist module not yet wired) — unrelated to this task; `staff_shell_widget_test` contains zero references to StaffScreen/panel_staff.
service_locator addition for the controller:
  import 'package:tavo/feature/panel_staff/di/register_staff_module.dart';
  registerStaffModule();

## Task 14 — Reviews UI + Tables/floor-plan UI
RED: `flutter test test/panel_reviews_test.dart test/panel_tables_test.dart` → compile errors (`panel_reviews` / `panel_tables` packages don't exist).
GREEN: 11 passed (7 + 4) (`00:05 +11: All tests passed!`).
Fixes vs brief snippet (no assertion changed):
- Added the missing `async_state_view.dart` import to `panel_reviews_test.dart` (`ListSkeleton`; same omission pattern as other briefs).
- `_pumpReviews`/`_pumpTables` gain the `pumpUntil`-skeleton amendment (EasyLocalization builds the child subtree asynchronously; mirrors panel_menu_test.dart).
- Respond-failure cubit test arms `repo.failure` AFTER `cubit.load()`: the verbatim version injects the one-shot failure before load, so the failure fires on `getReviews` (state → `ReviewsPanelError`) and the `as ReviewsPanelLoaded` cast can never succeed. Failure now fires on `respondReview` as the test name requires.
- Repos use named record destructure `(items: rows, pagination: …)` (brief positional form doesn't compile against panel_envelope.dart; menu pattern).
- `register_*_module.dart` drop the brief's unused `_can` helper (gate lives in the screens via `venue`; an unused private function would add an `unused_element` analyze issue). Added the `isRegistered` repo guard (menu pattern; re-runs safe).
- Unanswered review cards render BOTH `no_response_yet` text and the respond button (brief test expects both on an owner venue).
- Status rows render seats+status without table codes (editor + tray already render each code exactly once; keeps the `IN-2 findsOneWidget` tray assertion intact).
Suites touched all green: panel_reviews 7/7, panel_tables 4/4.
Analyze: 25 issues total, 0 in task-14 files (the +1 over the 24 baseline sits in `panel_settings_screen.dart` — a concurrent sibling task).
Full suite: `+152: All tests passed!` (EXIT:0; baseline 119 + this task's 11 + siblings' additions, no failures).
i18n: 16 keys × en/ar via script (`seats` already existed → script reported 15 added; all 16 keys verified present).
Controller wiring (NOT applied — service_locator untouched):
  import 'package:tavo/feature/panel_reviews/di/register_reviews_module.dart';
  import 'package:tavo/feature/panel_tables/di/register_tables_module.dart';
  registerReviewsModule();
  registerTablesModule();

## Task 16 — Settings UI (working hours, reservation settings, availability)
RED: `flutter test test/panel_settings_test.dart` → compile errors (`panel_settings` package doesn't exist: `SettingsPanelRepo` isn't a type, `PanelSettingsScreen`/`SettingsPanelCubit`/`SettingsPanelLoaded` not found; 0 tests ran).
GREEN: 6 passed (`00:03 +6: All tests passed!`).
Deviations from brief snippet (no assertion changed):
- Panel prefix per spawner class-ownership rule: real screen is `PanelSettingsScreen` in `lib/feature/panel_settings/ui/screens/panel_settings_screen.dart`; Task 11's `restaurant_panel/.../settings_screen.dart` placeholder untouched. Test imports adapted to the new path/class only.
- Brief-verbatim record-inference defects fixed (assertions untouched): repo `getSettings`/`getAvailability` use `List<WorkingDayEntry>.from(...)` + `const <String, dynamic>{}` (bare `const []`/`const {}` infer `List<dynamic>`/`Map<dynamic,dynamic>` and don't compile); test fake's `celebrationFeatures` likewise typed.
- Both saves live in a pinned `bottomNavigationBar` (same keys `save_hours`/`save_settings`, spinner while `saving`) instead of inside the scroll: the full form is taller than the 800x600 test viewport and the brief test taps `save_settings` without scrolling (tap missed at y=820 pre-fix). Form state reached via `GlobalKey<_LoadedFormState>`; view-only venues get no bottom bar.
- Cubit `load()` fetches settings + availability via `Future.wait` and seeds `kWeekDays` defaults for backend-missing days; saves set `saving` then clear it, failures keep the form + `actionError`.
i18n: 16 keys x en/ar via script (`working_hours`, `closed`, `settings_day_saturday` pre-existed; all 19 keys verified present in both files).
Suites touched all green: panel_settings 6/6. Full suite: `+152: All tests passed!` (an earlier mid-run showed 11 transient failures in siblings' in-progress suites — panel_reviews/panel_waitlist/onboarding — all green on re-run; no regressions in suites this task touches).
Analyze: 24 issues total = baseline, 0 in task-16 files (a transient `prefer_const_constructors_in_immutables` on `_LoadedForm` fixed by re-adding `const` to the declaration).
Controller wiring (NOT applied — service_locator untouched):
  import 'package:tavo/feature/panel_settings/di/register_settings_module.dart';
  registerSettingsModule();
