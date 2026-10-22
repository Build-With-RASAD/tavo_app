# TDD Evidence — Restaurant Intelligence, Wave 2

Plan: `docs/superpowers/plans/2026-10-22-restaurant-intelligence-wave2.md`
Spec: `docs/superpowers/specs/2026-10-22-restaurant-intelligence-wave2.md`

This file is **append-only**. Every task appends its RED output first (the real
failing output, not a paraphrase) and then its GREEN output.

## Baselines (measured 2026-10-22, before any Wave 2 change)

- Backend: `npm test -- tests/unit` → **48 suites / 490 tests, all green**.
- Flutter: `flutter test` → **199 passed, 1 failed**
  (`test/panel_tables_redesign_test.dart` — compile error: `onOpenOrders` is
  not a defined named parameter). The failure is **pre-existing**: commit
  `48c5616` ("resturant admin") landed Task 28's backend files but never
  mounted them and never wrote Task 28's Flutter half, orphaning the test.
- Flutter: `flutter analyze` → **26 issues (1 error)** vs the gate of exactly 24.

## Task 29-A — mount the Task 28 tables CRUD routes

### RED — the new mount assertion

`npm test -- tests/unit/tables-crud.test.js`

The new test mounts **only** the panel router (`src/routes/restaurant-owner.routes.js`),
the way `index.js` mounts it, so a missing mount shows up as a 404 instead of
being masked by the standalone mount the Task 28 suite uses.

```
FAIL tests/unit/tables-crud.test.js
  ● tables CRUD is mounted on the panel router (Task 29-A) › serves PUT/DELETE /physical-tables/:id through the panel mount, still behind manage_tables

    expect(received).toBe(expected) // Object.is equality

    Expected: 403
    Received: 404

      438 |       .set("Authorization", `Bearer ${viewerToken}`)
      439 |       .send({ seats: 6 });
    > 440 |     expect(forbiddenPut.statusCode).toBe(403);
          |                                     ^
      441 |     expect(forbiddenPut.body).toEqual(expect.objectContaining({ success: false, statusCode: 403 }));
      442 |
      443 |     const forbiddenDelete = await request(app)

      at Object.<anonymous> (tests/unit/tables-crud.test.js:440:37)

Test Suites: 1 failed, 1 total
Tests:       1 failed, 21 passed, 22 total
Snapshots:   0 total
Time:        3.169 s, estimated 8 s
Ran all test suites matching tests/unit/tables-crud.test.js.
```

### RED — full suite

`npm test -- tests/unit`

```
Summary of all failing tests
FAIL tests/unit/tables-crud.test.js (19.106 s)
  ● tables CRUD is mounted on the panel router (Task 29-A) › serves PUT/DELETE /physical-tables/:id through the panel mount, still behind manage_tables

    expect(received).toBe(expected) // Object.is equality

    Expected: 403
    Received: 404

      438 |       .set("Authorization", `Bearer ${viewerToken}`)
      439 |       .send({ seats: 6 });
    > 440 |     expect(forbiddenPut.statusCode).toBe(403);
          |                                     ^
      441 |     expect(forbiddenPut.body).toEqual(expect.objectContaining({ success: false, statusCode: 403 }));
      442 |
      443 |     const forbiddenDelete = await request(app)

      at Object.<anonymous> (tests/unit/tables-crud.test.js:440:37)


Test Suites: 1 failed, 47 passed, 48 total
Tests:       1 failed, 490 passed, 491 total
Snapshots:   0 total
Time:        69.496 s
Ran all test suites matching tests/unit.
```

### GREEN — the mounted file

`npm test -- tests/unit/tables-crud.test.js`

```
Test Suites: 1 passed, 1 total
Tests:       22 passed, 22 total
Snapshots:   0 total
Time:        20.355 s, estimated 29 s
Ran all test suites matching tests/unit/tables-crud.test.js.
```

### GREEN — full suite

`npm test -- tests/unit --maxWorkers=4`

(The worker count is pinned because this machine is shared with the other Wave 2
subagents; at the default worker count the in-memory Mongo instances collide
and the run times out on machine load, not on an assertion. A plain
`npm test -- tests/unit` run afterwards reported the same 516 tests with only
`tests/unit/performance.test.js` failing — a wall-clock assertion
(`10 000 × new Date()` must take < 100 ms; it measured 225 ms under load).)

```
Test Suites: 51 passed, 51 total
Tests:       516 passed, 516 total
Snapshots:   0 total
Time:        70.188 s, estimated 332 s
Ran all test suites matching tests/unit.
```

The suite totals are above the 48 suites / 490 tests baseline because the
sibling Wave 2 subagents (Task 30-A, Task 31-A) added their own test files to
the same working tree while this task was running. Task 29-A's own
contribution is **+1 test** (`tables-crud.test.js`: 21 → 22).

## Task 29-B — Task 28 Flutter tables redesign

Flutter half of Task 28 (the backend half was mounted by Task 29-A). The RED
test `test/panel_tables_redesign_test.dart` already existed in the tree,
orphaned by commit `d2f3141`; this task makes it green.

### RED — the orphaned test (real output)

`flutter test test/panel_tables_redesign_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart
test/panel_tables_redesign_test.dart:164:5: Error: No named parameter with the name 'onOpenOrders'.
    onOpenOrders: onOpenOrders,
    ^^^^^^^^^^^^
lib/feature/restaurant_panel/ui/screens/tables_screen.dart:32:9: Context: Found this candidate, but the arguments don't match.
  const TablesScreen(
        ^^^^^^^^^^^^
00:00 +0 -1: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart [E]
  Failed to load "/Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart":
  Compilation failed for testPath=/Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: test/panel_tables_redesign_test.dart:164:5: Error: No named parameter with the name 'onOpenOrders'.
      onOpenOrders: onOpenOrders,
      ^^^^^^^^^^^^
  lib/feature/restaurant_panel/ui/screens/tables_screen.dart:32:9: Context: Found this candidate, but the arguments don't match.
    const TablesScreen(
          ^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart
```

### RED — after the implementation: one genuine defect in the RED test itself

The first implementation run reached 13/14. The remaining failure is a defect
in the orphaned RED test, not in the implementation: the test constructs a
`TablesPanelCubit` and calls `moveTable` **without ever loading it**, so the
cubit is still in `TablesPanelInitial`, `moveTable` is (correctly) a no-op on
an unloaded state, and the cast at line 526 throws. The test therefore
exercised nothing. Fixed by adding the missing `await cubit.load();` — every
assertion is kept verbatim (see "Test defect" in the report).

`flutter test test/panel_tables_redesign_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart
00:00 +0: (setUpAll)
00:00 +0: view mode (default) colors tables: occupied orange, reserved red, available green, inactive grey + 0.55 dimming
00:04 +1: sizes table cards by the seats buckets 44/52/64/76
00:04 +2: zone legend counts zones; backdrops only for positioned zones
00:04 +3: tap opens the detail sheet with edit/toggle/delete actions
00:05 +4: occupied sheet shows the hint and fires onOpenOrders (no start-order)
00:05 +5: view-only staff get no edit toggle, save, add or sheet actions
00:05 +6: edit mode gates multi-select and bulk zone/status on the repo
00:06 +7: delete flow asks for confirmation and only then hits the repo
00:06 +8: edit form posts code/seats/zone through updatePhysicalTable
00:07 +9: add-table form creates through createPhysicalTable
00:07 +10: CRUD cubit calls hit the fake repo with the right args
00:08 +11: snap math rounds to 0.05 steps and moveTable applies it
00:08 +11 -1: snap math rounds to 0.05 steps and moveTable applies it [E]
  type 'TablesPanelInitial' is not a subtype of type 'TablesPanelLoaded' in type cast
  test/panel_tables_redesign_test.dart 526:30  main.<fn>

00:08 +11 -1: load failure shows the inline error and retry recovers
00:08 +12 -1: empty types show the composed empty state
00:09 +13 -1: (tearDownAll)
00:09 +13 -1: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: snap math rounds to 0.05 steps and moveTable applies it
```

### GREEN — focused suite

`flutter test test/panel_tables_redesign_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart
00:00 +0: (setUpAll)
00:00 +0: view mode (default) colors tables: occupied orange, reserved red, available green, inactive grey + 0.55 dimming
00:04 +1: sizes table cards by the seats buckets 44/52/64/76
00:05 +2: zone legend counts zones; backdrops only for positioned zones
00:06 +3: tap opens the detail sheet with edit/toggle/delete actions
00:06 +4: occupied sheet shows the hint and fires onOpenOrders (no start-order)
00:07 +5: view-only staff get no edit toggle, save, add or sheet actions
00:07 +6: edit mode gates multi-select and bulk zone/status on the repo
00:08 +7: delete flow asks for confirmation and only then hits the repo
00:08 +8: edit form posts code/seats/zone through updatePhysicalTable
00:11 +9: add-table form creates through createPhysicalTable
00:14 +10: CRUD cubit calls hit the fake repo with the right args
00:14 +11: snap math rounds to 0.05 steps and moveTable applies it
00:14 +12: load failure shows the inline error and retry recovers
00:14 +13: empty types show the composed empty state
00:15 +14: (tearDownAll)
00:15 +14: All tests passed!
```

**14 / 14 green** (the orphaned file holds 14 cases, not the 12 the brief
estimated). The `[🌎 Easy Localization] [DEBUG]` log lines that
`easy_localization` prints on every test were elided from the transcripts
above; they are library stdout noise, not test results.

### GREEN — full suite

`flutter test`

```
00:22 +240: All tests passed!
```

**240 passed, 0 failed.** The pre-existing `test/panel_tables_test.dart`
(4 cases: positioned tables / tray, drag + save floor plan, empty state,
`moveTable` clamping) stays green and unmodified — the T28 redesign keeps
the `floor_editor`, `table_<id>`, `floor_tray` and `save_floor` keys and the
drag-to-move + save behaviour that file pins.

The recorded baseline was `199 passed, 1 failed` (the same orphaned file).
The suite is now **240 passed / 0 failed**; the growth above 199 is the sum of
Task 29-B's own **+14** plus the files the sibling Wave 2 agents (30-A, 30-C,
31-A, 33-A …) added to the same working tree while this task ran.

> A full-suite run taken while the sibling Task 30-C agent was mid-write of
> `lib/core/navigation/deep_link_service.dart` failed to compile *their* file
> (`Failed to load …/test/deep_link_service_test.dart`) — a transient race on a
> file this task does not touch. It was re-run after their file settled:
> **240 passed, 0 failed**. Nothing in this task's own files was changed to
> achieve that.

### `flutter analyze`

| | issues | attributable to Task 29-B |
|---|---|---|
| before (excluding the concurrent `test/deep_link_service_test.dart` RED file and this task's own RED error) | 38 | — |
| after | 38 | **0** |

The file-by-file breakdown before and after is byte-identical
(`diff` of the per-file issue counts → no diff), so this task adds **no** new
analyzer issue. The absolute number moved 105 → 38 only because the sibling
agent finished `test/deep_link_service_test.dart` (66 errors cleared) and this
task's own `onOpenOrders` compile error disappeared.


## Task 30-A — App Links well-known files + public slug resolution

Command (RED): `npm test -- tests/unit/well-known.test.js tests/unit/public-slug.test.js`

```
> tavo@1.0.0 test
> node --experimental-vm-modules node_modules/jest/bin/jest.js tests/unit/well-known.test.js tests/unit/public-slug.test.js

FAIL tests/unit/well-known.test.js
  ● Test suite failed to run

    Cannot find module '../../src/routes/well-known.route.js' from 'tests/unit/well-known.test.js'

      at Resolver._throwModNotFoundError (node_modules/jest-resolve/build/index.js:895:11)

(node:82597) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
FAIL tests/unit/public-slug.test.js
  ● Test suite failed to run

    Cannot find module '../../src/routes/public-slug.route.js' from 'tests/unit/public-slug.test.js'

      at Resolver._throwModNotFoundError (node_modules/jest-resolve/build/index.js:895:11)

(node:82598) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
Test Suites: 2 failed, 2 total
Tests:       0 total
Snapshots:   0 total
Time:        2.231 s
Ran all test suites matching tests/unit/well-known.test.js|tests/unit/public-slug.test.js.
```

The same RED also shows up in the full-suite run (`npm test -- tests/unit`), where
both new suites fail with the identical `Cannot find module` error.

Command (GREEN): `npm test -- tests/unit/well-known.test.js tests/unit/public-slug.test.js`

```
> tavo@1.0.0 test
> node --experimental-vm-modules node_modules/jest/bin/jest.js tests/unit/well-known.test.js tests/unit/public-slug.test.js

(node:84283) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
(node:84284) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
  console.log
    Connected to in-memory test database

      at connectTestDatabase (tests/setup/testDatabase.js:25:13)

  console.log
    Connected to in-memory test database

      at connectTestDatabase (tests/setup/testDatabase.js:25:13)

  console.log
    Disconnected from test database

      at disconnectTestDatabase (tests/setup/testDatabase.js:41:11)

  console.log
    Disconnected from test database

      at disconnectTestDatabase (tests/setup/testDatabase.js:41:11)

Test Suites: 2 passed, 2 total
Tests:       14 passed, 14 total
Snapshots:   0 total
Time:        28.691 s
Ran all test suites matching tests/unit/well-known.test.js|tests/unit/public-slug.test.js.
```

Command (GREEN, full unit suite): `npm test -- tests/unit`

```
Test Suites: 51 passed, 51 total
Tests:       516 passed, 516 total
Snapshots:   0 total
Time:        196.406 s, estimated 283 s
Ran all test suites matching tests/unit.
```

The suite grew from the recorded baseline of **48 suites / 490 tests** to
**51 suites / 516 tests**: **+2 suites / +14 tests** are Task 30-A's
(`well-known.test.js` 9 assertions, `public-slug.test.js` 6 assertions); the
remaining **+1 suite / +12 tests** is `order-lifecycle.test.js`, Task 31-A's
file, written concurrently in the same working tree.

An intermediate full-suite run taken while Task 31-A was mid-implementation
showed `Test Suites: 1 failed, 50 passed, 51 total / Tests: 11 failed, 505
passed, 516 total`, the single failure being Task 31-A's own RED
(`order-lifecycle.test.js` → `Order` lifecycle timestamps not yet declared).
It is not caused by Task 30-A, which touches no model, no order service and no
owner route. Two further suites (`legacy-mutation-auth`,
`order-create-panel`) and `panel-route-permissions` flaked in an even earlier
run with `Instance failed to start within 10000ms` (MongoMemoryServer
contention with the other concurrent agents) and, for `panel-route-permissions`,
a transient `GET /orders → 404` while Task 29-A was mid-edit of
`restaurant-owner.routes.js`. All three were re-run in isolation and are green:

```
npm test -- tests/unit/legacy-mutation-auth.test.js tests/unit/order-create-panel.test.js tests/unit/panel-route-permissions.test.js --runInBand

Test Suites: 3 passed, 3 total
Tests:       28 passed, 28 total
```

Task 30-A's own 14 assertions, in full:

- `well-known.test.js` (9): assetlinks shape + `package_name === "com.rasad.tavo"`
  + non-empty 64-char-hex `sha256_cert_fingerprints` containing the **release**
  cert; assetlinks served without a redirect; `ASSETLINKS_SHA256` override
  honoured; AASA shape + `appID === "W3JGMK356T.com.rasad.tavo"` + `paths`
  contains `/menu/*` and `/r/*`; **AASA `Content-Type` is exactly
  `application/json`**; **AASA answered 200 with no `Location` header**;
  `apple-app-site-association.json` is **404**; both files need no auth;
  `/.well-known` is mounted in `index.js`.
- `public-slug.test.js` (6): 200 shape with exactly
  `{_id, name{en,ar}, logo, categoryIds, rating}`; **no phone / contact /
  staff / settings leak**; 404 `Restaurant not found` for an unknown slug; a
  non-plain slug is rejected with 400 **before** the database is touched; a
  valid slug is case-normalised; `/v1/api/public` is mounted in `index.js`
  without auth middleware.

## Task 30-C — Flutter deep-link service

### RED — the deep-link tests, before the implementation exists

Command: `flutter test test/deep_link_service_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/deep_link_service_test.dart
test/deep_link_service_test.dart:16:8: Error: Error when reading 'lib/core/navigation/deep_link_service.dart': No such file or directory
import 'package:tavo/core/navigation/deep_link_service.dart';
       ^
test/deep_link_service_test.dart:17:8: Error: Error when reading 'lib/core/navigation/deep_link_target.dart': No such file or directory
import 'package:tavo/core/navigation/deep_link_target.dart';
       ^
test/deep_link_service_test.dart:23:34: Error: Type 'DeepLinkSource' not found.
class _FakeLinkSource implements DeepLinkSource {
                                 ^^^^^^^^^^^^^^
test/deep_link_service_test.dart:55:22: Error: Undefined name 'DeepLinkService'.
      final target = DeepLinkService.parse(_menuUrl);
                     ^^^^^^^^^^^^^^^
test/deep_link_service_test.dart:57:26: Error: 'RestaurantSlugTarget' isn't a type.
      expect(target, isA<RestaurantSlugTarget>());
                         ^^^^^^^^^^^^^^^^^^^^
test/deep_link_service_test.dart:63:22: Error: Undefined name 'DeepLinkService'.
      final target = DeepLinkService.parse(
                     ^^^^^^^^^^^^^^^
test/deep_link_service_test.dart:67:26: Error: 'RestaurantSlugTarget' isn't a type.
      expect(target, isA<RestaurantSlugTarget>());
                         ^^^^^^^^^^^^^^^^^^^^
test/deep_link_service_test.dart:72:22: Error: Undefined name 'DeepLinkService'.
      final target = DeepLinkService.parse(
                     ^^^^^^^^^^^^^^^
test/deep_link_service_test.dart:76:26: Error: 'RestaurantDetailsTarget' isn't a type.
[... the compiler repeats the same diagnostics verbatim in the
"Compilation failed for testPath=..." block — 64 errors ...]
        final service = DeepLinkService(
                        ^^^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/deep_link_service_test.dart: loading /Users/elmarakbeno/development/tavo/tavo-app/test/deep_link_service_test.dart

```

### GREEN — the same file after the implementation

Command: `flutter test test/deep_link_service_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/deep_link_service_test.dart
00:00 +0: DeepLinkService.parse maps the public menu URL to a slug target
00:00 +1: DeepLinkService.parse tolerates a query string and a fragment
00:00 +2: DeepLinkService.parse maps the custom scheme to a restaurant id target
00:00 +3: DeepLinkService.parse maps the custom scheme with an empty authority to an id target
00:00 +4: DeepLinkService.parse ignores an unknown path on the allowed host
00:00 +5: DeepLinkService.parse ignores a foreign host
00:00 +6: DeepLinkService.parse ignores a look-alike host with the allowed host as a prefix
00:00 +7: DeepLinkService.parse ignores a look-alike host with the allowed host as a suffix
00:00 +8: DeepLinkService.parse ignores the allowed host smuggled into the user info
00:00 +9: DeepLinkService.parse ignores an explicit port
00:00 +10: DeepLinkService.parse ignores an empty slug
00:00 +11: DeepLinkService.parse ignores plain http — only https and the custom scheme are allowed
00:00 +12: DeepLinkService.parse ignores an unknown scheme
00:00 +13: DeepLinkService.parse ignores a malformed uri without throwing
00:00 +14: DeepLinkService.parse accepts the allowed host whatever its case
00:00 +15: DeepLinkService replays the cold-start link exactly once
00:00 +16: DeepLinkService init() twice does not replay the cold-start link again
00:00 +17: DeepLinkService replays a link delivered on both channels exactly once
00:00 +18: DeepLinkService delivers the cold-start link to a listener that attaches late
00:00 +19: DeepLinkService routes a warm link from the stream
00:00 +20: DeepLinkService resolves a warm slug link to a restaurant id
00:00 +21: DeepLinkService emits the none target when the slug cannot be resolved
00:00 +22: DeepLinkService emits the none target when the resolver throws
00:00 +23: DeepLinkService emits the none target when the resolver never completes
00:00 +24: DeepLinkService emits the none target for an unknown host
00:00 +25: DeepLinkService reports the unresolved link so the caller can fall back to the web page
00:00 +26: DeepLinkService reports the same unresolved link only once
00:00 +27: All tests passed!
```

**27 tests, all green** (15 parser cases + 12 service cases).

### GREEN — the whole Flutter suite

Command: `flutter test`

```
[90m[🌎 Easy Localization] [DEBUG] Load Localization Delegate[0m
[90m[🌎 Easy Localization] [DEBUG] Build[0m
[90m[🌎 Easy Localization] [DEBUG] Init Localization Delegate[0m
[90m[🌎 Easy Localization] [DEBUG] Init provider[0m
00:30 +240: /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: (tearDownAll)
00:31 +240: All tests passed!
```

**240 tests passed, 0 failed.** The pre-existing baseline was *199 passed,
1 failed* (`test/panel_tables_redesign_test.dart`, Task 29-B's file); that
file is green now, so the only delta this task contributes is its own 27
tests.

### `flutter analyze`

```
before this task's files existed:  39 issues found (1 error)
after:                             38 issues found (0 errors)
issues in lib/core/navigation/**           0
issues in test/deep_link_service_test.dart 0
```

The absolute count moves because Task 29-B is editing
`lib/feature/panel_tables/**` in the same package at the same time; the
number that matters is that this task adds **zero** analyzer issues.

## Task 31-A — order lifecycle timestamps

Files: `src/models/order.model.js` (four optional `Date` fields),
`src/services/restaurant-panel.services.js` (one surgical edit inside
`updateOrderStatus`), `tests/unit/order-lifecycle.test.js` (new — 11 tests).

**RED** — `npm test -- tests/unit/order-lifecycle.test.js` → **1 suite failed,
11 tests failed / 11 total**: the four fields did not exist yet, so every
assertion received `undefined`. Real output:

```text
Test Suites: 1 failed, 1 total
Tests:       11 failed, 11 total
Snapshots:   0 total
Time:        27.584 s
Ran all test suites matching tests/unit/order-lifecycle.test.js.

  ● order lifecycle timestamps (Task 31-A) › declares the four lifecycle fields as optional Dates on Order

    expect(received).toBeDefined()

    Received: undefined

      51 |     const paths = Order.schema.paths;
      52 |     for (const field of LIFECYCLE_FIELDS) {
    > 53 |       expect(paths[field]).toBeDefined();
         |                            ^
      54 |       expect(paths[field].instance).toBe("Date");
      55 |       expect(paths[field].options.required).toBeFalsy();
      56 |     }

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:53:28)

  ● order lifecycle timestamps (Task 31-A) › pending → confirmed stamps acceptedAt and nothing else

    expect(received).toBeInstanceOf(expected)

    Expected constructor: Date

    Received value has no prototype
    Received value: undefined

      62 |     const updated = await updateOrderStatus(order._id, restaurantId, "confirmed");
      63 |
    > 64 |     expect(updated.acceptedAt).toBeInstanceOf(Date);
         |                                ^
      65 |     expect(updated.preparingAt).toBeNull();
      66 |     expect(updated.readyAt).toBeNull();
      67 |     expect(updated.servedAt).toBeNull();

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:64:32)

  ● order lifecycle timestamps (Task 31-A) › confirmed → preparing stamps preparingAt and leaves acceptedAt untouched

    expect(received).toBeInstanceOf(expected)

    Expected constructor: Date

    Received value has no prototype
    Received value: undefined

      81 |     const updated = await updateOrderStatus(order._id, restaurantId, "preparing");
      82 |
    > 83 |     expect(updated.preparingAt).toBeInstanceOf(Date);
         |                                 ^
      84 |     expect(updated.acceptedAt).toEqual(accepted);
      85 |     expect(updated.readyAt).toBeNull();
      86 |     expect(updated.servedAt).toBeNull();

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:83:33)

  ● order lifecycle timestamps (Task 31-A) › preparing → ready stamps readyAt and leaves earlier stamps untouched

    expect(received).toBeInstanceOf(expected)

    Expected constructor: Date

    Received value has no prototype
    Received value: undefined

      102 |     const updated = await updateOrderStatus(order._id, restaurantId, "ready");
      103 |
    > 104 |     expect(updated.readyAt).toBeInstanceOf(Date);
          |                             ^
      105 |     expect(updated.acceptedAt).toEqual(accepted);
      106 |     expect(updated.preparingAt).toEqual(preparing);
      107 |     expect(updated.servedAt).toBeNull();

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:104:29)

  ● order lifecycle timestamps (Task 31-A) › ready → served stamps servedAt and leaves earlier stamps untouched

    expect(received).toBeInstanceOf(expected)

    Expected constructor: Date

    Received value has no prototype
    Received value: undefined

      124 |     const updated = await updateOrderStatus(order._id, restaurantId, "served");
      125 |
    > 126 |     expect(updated.servedAt).toBeInstanceOf(Date);
          |                              ^
      127 |     expect(updated.acceptedAt).toEqual(accepted);
      128 |     expect(updated.preparingAt).toEqual(preparing);
      129 |     expect(updated.readyAt).toEqual(ready);

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:126:30)

  ● order lifecycle timestamps (Task 31-A) › never overwrites an earlier stamp across the full chain

    TypeError: Cannot read properties of undefined (reading 'getTime')

      152 |
      153 |     // The stamps stay ordered — a later stamp can never predate an earlier one.
    > 154 |     expect(persisted.acceptedAt.getTime()).toBeLessThanOrEqual(
          |                                 ^
      155 |       persisted.preparingAt.getTime()
      156 |     );
      157 |     expect(persisted.preparingAt.getTime()).toBeLessThanOrEqual(

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:154:33)

  ● order lifecycle timestamps (Task 31-A) › pending → cancelled stamps nothing at all

    expect(received).toBeNull()

    Received: undefined

      170 |     expect(updated.orderStatus).toBe("cancelled");
      171 |     for (const field of LIFECYCLE_FIELDS) {
    > 172 |       expect(updated[field]).toBeNull();
          |                              ^
      173 |     }
      174 |
      175 |     const persisted = await reload(order._id);

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:172:30)

  ● order lifecycle timestamps (Task 31-A) › cancelling from confirmed keeps the original acceptedAt and adds no new stamp

    expect(received).toBeNull()

    Received: undefined

      188 |     expect(updated.orderStatus).toBe("cancelled");
      189 |     expect(updated.acceptedAt).toEqual(accepted);
    > 190 |     expect(updated.preparingAt).toBeNull();
          |                                 ^
      191 |     expect(updated.readyAt).toBeNull();
      192 |     expect(updated.servedAt).toBeNull();
      193 |   });

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:190:33)

  ● order lifecycle timestamps (Task 31-A) › rejects an illegal transition and leaves the document untouched

    expect(received).toBeNull()

    Received: undefined

      203 |     expect(persisted.orderStatus).toBe("pending");
      204 |     for (const field of LIFECYCLE_FIELDS) {
    > 205 |       expect(persisted[field]).toBeNull();
          |                                ^
      206 |     }
      207 |   });
      208 |

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:205:32)

  ● order lifecycle timestamps (Task 31-A) › does not stamp the target field of an illegal transition

    expect(received).toBeNull()

    Received: undefined

      218 |     const persisted = await reload(order._id);
      219 |     expect(persisted.orderStatus).toBe("pending");
    > 220 |     expect(persisted.preparingAt).toBeNull();
          |                                   ^
      221 |     expect(persisted.acceptedAt).toBeNull();
      222 |   });
      223 |

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:220:35)

  ● order lifecycle timestamps (Task 31-A) › leaves a pre-existing order untouched when the transition is rejected

    expect(received).toBeNull()

    Received: undefined

      234 |     expect(persisted.orderStatus).toBe("confirmed");
      235 |     expect(persisted.acceptedAt).toEqual(accepted);
    > 236 |     expect(persisted.preparingAt).toBeNull();
          |                                   ^
      237 |     expect(persisted.readyAt).toBeNull();
      238 |     expect(persisted.servedAt).toBeNull();
      239 |   });

      at Object.<anonymous> (tests/unit/order-lifecycle.test.js:236:35)
```

Full-suite RED captured at the same moment — `npm test -- tests/unit`:

```text
Test Suites: 9 failed, 42 passed, 51 total
Tests:       34 failed, 482 passed, 516 total
Snapshots:   0 total
Time:        208.353 s
Ran all test suites matching tests/unit.
```

The other 8 failing suites in that capture are parallel-load flakes of the
shared tree (every suite boots its own `mongodb-memory-server`), not this
task: re-run alone with `--runInBand` they are green — 4 suites / 33 tests
passed and 4 suites / 28 tests passed. Their failure message is
`Instance failed to start within 10000ms`.

**GREEN** — `npm test -- tests/unit/order-lifecycle.test.js` → 1 suite /
11 tests passed:

```text
Test Suites: 1 passed, 1 total
Tests:       11 passed, 11 total
Snapshots:   0 total
Time:        2.203 s
Ran all test suites matching tests/unit/order-lifecycle.test.js.
```

**GREEN (full suite)** — `npm test -- tests/unit --runInBand` → **51 suites /
516 tests, all green** (exit code 0):

```text
Test Suites: 51 passed, 51 total
Tests:       516 passed, 516 total
Snapshots:   0 total
Time:        441.946 s
Ran all test suites matching tests/unit.
```

The parallel form of the same command (`npm test -- tests/unit`) is unstable
on this machine: 8–12 suites per run fail with
`Instance failed to start within 10000ms` while many `mongod` instances boot
at once, and the failing list changes from run to run (sibling Wave-2 agents
run their own suites concurrently). `--runInBand` is the authoritative green.

Baseline drift: the plan baseline was 48 suites / 490 tests; this run shows
51 suites / 516 tests because sibling Wave-2 tasks landed their own suites
and tests in the shared tree while this task ran. This task itself adds
exactly **1 suite / 11 tests** and changes 2 source files.

Deviation from the brief: Step 2 says "no `required`, no default" while
Step 1 pins "the other three are `null`" ("absent → `null`"). A bare
`{ type: Date }` path reads as `undefined` in Mongoose, so each field uses
`default: null` — nothing is auto-filled on creation (no timestamp is
fabricated) and an untouched stamp reads as `null` exactly as the brief
requires.

## Task 33-A — motion foundation

Files: `lib/core/animation/motion_tokens.dart`,
`lib/core/animation/motion.dart`,
`lib/core/animation/primitives/{spring_press,spring_reveal,spring_counter,spring_sheet}.dart`,
`lib/core/animation/shaders/{shader_program_loader,shader_painters}.dart`,
`lib/core/animation/shaders/{gooey,liquid,aurora}.frag`,
`lib/core/theme/motion_theme_extension.dart`,
`test/motion_system_test.dart` (22 cases).

### RED — the new file does not exist yet

Command: `flutter test test/motion_system_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart
test/motion_system_test.dart:6:8: Error: Error when reading 'lib/core/animation/motion.dart': No such file or directory
import 'package:tavo/core/animation/motion.dart';
       ^
test/motion_system_test.dart:7:8: Error: Error when reading 'lib/core/animation/motion_tokens.dart': No such file or directory
import 'package:tavo/core/animation/motion_tokens.dart';
       ^
test/motion_system_test.dart:8:8: Error: Error when reading 'lib/core/animation/primitives/spring_counter.dart': No such file or directory
import 'package:tavo/core/animation/primitives/spring_counter.dart';
       ^
test/motion_system_test.dart:9:8: Error: Error when reading 'lib/core/animation/primitives/spring_press.dart': No such file or directory
import 'package:tavo/core/animation/primitives/spring_press.dart';
       ^
test/motion_system_test.dart:10:8: Error: Error when reading 'lib/core/animation/primitives/spring_reveal.dart': No such file or directory
import 'package:tavo/core/animation/primitives/spring_reveal.dart';
       ^
test/motion_system_test.dart:11:8: Error: Error when reading 'lib/core/animation/primitives/spring_sheet.dart': No such file or directory
import 'package:tavo/core/animation/primitives/spring_sheet.dart';
       ^
test/motion_system_test.dart:12:8: Error: Error when reading 'lib/core/animation/shaders/shader_painters.dart': No such file or directory
import 'package:tavo/core/animation/shaders/shader_painters.dart';
       ^
test/motion_system_test.dart:13:8: Error: Error when reading 'lib/core/animation/shaders/shader_program_loader.dart': No such file or directory
import 'package:tavo/core/animation/shaders/shader_program_loader.dart';
       ^
test/motion_system_test.dart:14:8: Error: Error when reading 'lib/core/theme/motion_theme_extension.dart': No such file or directory
import 'package:tavo/core/theme/motion_theme_extension.dart';
       ^
test/motion_system_test.dart:73:35: Error: Type 'ShaderProgramLoader' not found.
class _RecordingLoader implements ShaderProgramLoader {
                                  ^^^^^^^^^^^^^^^^^^^
test/motion_system_test.dart:41:23: Error: Undefined name 'SpringPress'.
      of: find.byType(SpringPress),
                      ^^^^^^^^^^^
test/motion_system_test.dart:53:27: Error: Undefined name 'SpringReveal'.
          of: find.byType(SpringReveal),
                          ^^^^^^^^^^^^
test/motion_system_test.dart:65:23: Error: Undefined name 'SpringSheet'.
      of: find.byType(SpringSheet),
                      ^^^^^^^^^^^
test/motion_system_test.dart:86:14: Error: Undefined name 'AppDurations'.
      expect(AppDurations.fast, const Duration(milliseconds: 150));
             ^^^^^^^^^^^^
test/motion_system_test.dart:87:14: Error: Undefined name 'AppDurations'.
      expect(AppDurations.normal, const Duration(milliseconds: 250));
             ^^^^^^^^^^^^
test/motion_system_test.dart:88:14: Error: Undefined name 'AppDurations'.
      expect(AppDurations.slow, const Duration(milliseconds: 400));
             ^^^^^^^^^^^^
test/motion_system_test.dart:89:14: Error: Undefined name 'AppDurations'.
      expect(AppDurations.hero, const Duration(milliseconds: 500));
             ^^^^^^^^^^^^
test/motion_system_test.dart:93:14: Error: Undefined name 'AppCurves'.
      expect(AppCurves.easeOut, Curves.easeOutCubic);
             ^^^^^^^^^
test/motion_system_test.dart:94:14: Error: Undefined name 'AppCurves'.
      expect(AppCurves.easeIn, Curves.easeInCubic);
             ^^^^^^^^^
test/motion_system_test.dart:95:14: Error: Undefined name 'AppCurves'.
      expect(AppCurves.emphasized, const Cubic(0.2, 0.0, 0.0, 1.0));
             ^^^^^^^^^
test/motion_system_test.dart:99:14: Error: Undefined name 'AppSprings'.
      expect(AppSprings.snappy.mass, 1);
             ^^^^^^^^^^
[...]
  Failed to load "/Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart":
  Compilation failed for testPath=/Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart: test/motion_system_test.dart:6:8: Error: Error when reading 'lib/core/animation/motion.dart': No such file or directory
  ...
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart: loading /Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart
```

(The full compiler output is 528 lines — 9 missing libraries plus every
reference to a name that does not exist yet.)

### GREEN — the focused suite

Command: `flutter test test/motion_system_test.dart`

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/motion_system_test.dart
00:00 +0: motion tokens AppDurations exposes the four duration tokens
00:00 +1: motion tokens AppCurves exposes the three curve tokens
00:00 +2: motion tokens AppSprings exposes the three spring tokens
00:00 +3: Motion isReduced mirrors MediaQuery.disableAnimations
00:01 +4: Motion adapt collapses the duration to zero under reduced motion
00:01 +5: Motion springFor returns the no-motion spring under reduced motion
00:01 +6: MotionTheme of returns the theme extension when one is registered
00:01 +7: MotionTheme of falls back to the default tokens when none is registered
00:01 +8: MotionTheme copyWith overrides a single token and lerp blends two themes
00:01 +9: SpringPress scales down while pressed and springs back on release
00:01 +10: SpringPress is a no-op under reduced motion
00:01 +11: SpringPress animates the transform only, never the layout
00:01 +12: SpringCounter settles on the target inside the hero budget
00:01 +13: SpringCounter jumps straight to the target under reduced motion
00:01 +14: SpringReveal reveals the children one after the other
00:01 +15: SpringReveal shows every child immediately under reduced motion
00:01 +16: SpringSheet settles on the identity transform
00:02 +17: SpringSheet is at the final transform immediately under reduced motion
00:02 +18: shaders the painters degrade to a plain fill without a program
00:02 +19: shaders the asset loader degrades to null when the program is missing
00:02 +20: shaders a surface renders through an injected loader
00:02 +21: disposal every primitive releases its controller when removed
00:02 +22: All tests passed!
```

**22 / 22 green.**

### The settle budget is a real guard, not a formality

`SpringCounter` settles inside `AppDurations.hero * 2` (1000 ms of simulated
time). The measured settle time of every token spring, for a span of `1` and
for a span of `1250` (the KPI counter), is the same — the tolerance scales
with the distance the spring travels:

```
snappy span=1.0 settled at 455 ms
snappy span=1250.0 settled at 455 ms
gentle span=1.0 settled at 577 ms
gentle span=1250.0 settled at 577 ms
bouncy span=1.0 settled at 770 ms
bouncy span=1250.0 settled at 770 ms
```

Proof that the test catches a spring that never settles: with
`AppSprings.gentle.damping` temporarily changed from `24` to `0.0001`
(essentially undamped), the same test fails with

```
The following TestFailure was thrown running a test:
pumpAndSettle timed out
  ...
  test/motion_system_test.dart:383:7
The test description was:
  settles on the target inside the hero budget
```

The damping was restored to `24` immediately afterwards; the file is byte
identical to the committed version.

### GREEN — the whole Flutter suite

Command: `flutter test`

```
00:37 +285 -2: /Users/elmarakbeno/development/tavo/tavo-app/test/onboarding_screen_regression_test.dart: (tearDownAll)
00:37 +285 -2: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/dashboard_screen_widget_test.dart: renders the three zones with the payload values
  /Users/elmarakbeno/development/tavo/tavo-app/test/dashboard_screen_widget_test.dart: the shell callbacks fire from the dashboard
```

**285 passed, 2 failed.** Both failures belong to the **sibling Task 32
agent**, which is rebuilding `lib/feature/panel_dashboard/**` in the same
working tree right now. The cause is a layout overflow in the sibling's own
widget:

```
The following assertion was thrown during layout:
A RenderFlex overflowed by 19 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///Users/elmarakbeno/development/tavo/tavo-app/lib/feature/panel_dashboard/ui/widgets/kpi_tiles.dart:108:26
```

Neither failure touches a file of this task. Re-running the suite without the
sibling's in-flight file is fully green:

```
$ find test -name "*_test.dart" | grep -v dashboard_screen_widget_test | xargs flutter test
00:18 +283: /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: (tearDownAll)
00:18 +283: All tests passed!
```

**283 passed, 0 failed** (the sibling's file holds 2 cases).

> Two earlier full-suite runs during this task read `246 passed / 6 failed`
> and `285 passed / 3 failed`. Those were compile errors and a missing
> `OccupancyRing` widget in the sibling's in-flight dashboard code, fixed by
> the sibling while this task was running. The counts above are the final
> ones.

### `flutter analyze`

| | issues | attributable to Task 33-A |
|---|---|---|
| before this task's files existed | 25 | — |
| after | 35 | **0** |

The absolute number moved because the sibling Task 32 agent is editing
`lib/feature/panel_dashboard/**` and `test/panel_dashboard*_test.dart` in the
same package at the same time (an earlier measurement during this task read
52, when the sibling's tree was mid-rewrite). The number that matters is the
per-file breakdown — **zero** issues in:

```
lib/core/animation/motion.dart
lib/core/animation/motion_tokens.dart
lib/core/animation/primitives/spring_press.dart
lib/core/animation/primitives/spring_reveal.dart
lib/core/animation/primitives/spring_counter.dart
lib/core/animation/primitives/spring_sheet.dart
lib/core/animation/shaders/shader_program_loader.dart
lib/core/animation/shaders/shader_painters.dart
lib/core/theme/motion_theme_extension.dart
test/motion_system_test.dart
```

### The shaders compile

The three `.frag` files are validated with the same compiler the Flutter
tool uses (`impellerc`, shipped in the engine artifacts), for every runtime
stage the tool targets:

```
$ impellerc --sksl --runtime-stage-metal --runtime-stage-gles --iplr \
    --sl=gooey.out --spirv=gooey.out.spirv \
    --input=lib/core/animation/shaders/gooey.frag --input-type=frag \
    --include=lib/core/animation/shaders --include=$shader_lib
exit=0
$ impellerc ... --input=lib/core/animation/shaders/liquid.frag ...
exit=0
$ impellerc ... --input=lib/core/animation/shaders/aurora.frag ...
exit=0
```

The same three shaders also compile for `--runtime-stage-gles3
--runtime-stage-vulkan` (exit 0 each). The reflection confirms the uniform
names the painters address by name:

```
iTime      vec_size 1  location 0
uSize      vec_size 2  location 1
uProgress  vec_size 1  location 2
```

The `shaders:` block in `pubspec.yaml` is **controller-owned** and was not
touched by this task:

```yaml
flutter:
  shaders:
    - lib/core/animation/shaders/gooey.frag
    - lib/core/animation/shaders/liquid.frag
    - lib/core/animation/shaders/aurora.frag
```

## Task 30-D — "Open in Tavo app" on the public menu page

Command (RED): `npm test -- tests/unit/public-menu.test.js`

```

> tavo@1.0.0 test
> node --experimental-vm-modules node_modules/jest/bin/jest.js tests/unit/public-menu.test.js

(node:1077) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
  console.log
    Connected to in-memory test database

      at connectTestDatabase (tests/setup/testDatabase.js:25:13)

  console.log
    Disconnected from test database

      at disconnectTestDatabase (tests/setup/testDatabase.js:41:11)

FAIL tests/unit/public-menu.test.js
  ● public menu page — open in Tavo app (Task 30-D) › renders an 'Open in Tavo app' CTA pointing at tavo://restaurant/<id>

    expect(received).toContain(expected) // indexOf

    Expected substring: "href=\"tavo://restaurant/6ad9ae109aed7b3b338aba6b\""
    Received string:    "<!DOCTYPE html>
    <html lang=\"ar\" dir=\"rtl\">
    <head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>برغر لاب</title>
    <style>body{font-family:system-ui,sans-serif;background:#faf7f2;color:#222;margin:0}header{text-align:center;padding:32px 16px;background:#1b365d;color:#fff}.logo{width:72px;height:72px;border-radius:50%;object-fit:cover}main{max-width:640px;margin:0 auto;padding:16px}h2{border-bottom:2px solid #1b365d;padding-bottom:4px}.item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid #eee}.item-body{flex:1}.item-name{font-weight:700}.item-desc{color:#666;font-size:14px}.price{font-weight:700;white-space:nowrap}.item-img{width:64px;height:64px;border-radius:8px;object-fit:cover}</style>
    </head>
    <body><header><img class=\"logo\" src=\"/uploads/logo.png\" alt=\"\"><h1>برغر لاب</h1><p>أفضل برجر في الرياض</p></header><main></main></body>
    </html>"

      158 |   it("renders an 'Open in Tavo app' CTA pointing at tavo://restaurant/<id>", async () => {
      159 |     const ar = await request(app).get(`/menu/${SLUG}`);
    > 160 |     expect(ar.text).toContain(`href="tavo://restaurant/${restaurant._id}"`);
          |                     ^
      161 |     expect(ar.text).toContain("افتح في تطبيق تavo");
      162 |
      163 |     const en = await request(app).get(`/menu/${SLUG}?lang=en`);

      at Object.<anonymous> (tests/unit/public-menu.test.js:160:21)

  ● public menu page — open in Tavo app (Task 30-D) › renders the Smart Banner meta and the intent URL for THIS restaurant

    expect(received).toContain(expected) // indexOf

    Expected substring: "<meta name=\"mobile-web-app-capable\" content=\"yes\">"
    Received string:    "<!DOCTYPE html>
    <html lang=\"en\" dir=\"ltr\">
    <head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Burger Lab</title>
    <style>body{font-family:system-ui,sans-serif;background:#faf7f2;color:#222;margin:0}header{text-align:center;padding:32px 16px;background:#1b365d;color:#fff}.logo{width:72px;height:72px;border-radius:50%;object-fit:cover}main{max-width:640px;margin:0 auto;padding:16px}h2{border-bottom:2px solid #1b365d;padding-bottom:4px}.item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid #eee}.item-body{flex:1}.item-name{font-weight:700}.item-desc{color:#666;font-size:14px}.price{font-weight:700;white-space:nowrap}.item-img{width:64px;height:64px;border-radius:8px;object-fit:cover}</style>
    </head>
    <body><header><img class=\"logo\" src=\"/uploads/logo.png\" alt=\"\"><h1>Burger Lab</h1><p>Best burgers in Riyadh</p></header><main></main></body>
    </html>"

      169 |   it("renders the Smart Banner meta and the intent URL for THIS restaurant", async () => {
      170 |     const res = await request(app).get(`/menu/${SLUG}?lang=en`);
    > 171 |     expect(res.text).toContain('<meta name="mobile-web-app-capable" content="yes">');
          |                      ^
      172 |     expect(res.text).toContain(
      173 |       `intent://${HOST}/menu/${SLUG}#Intent;scheme=https;host=${HOST};` +
      174 |         `path=/menu/${SLUG};package=${PKG};` +

      at Object.<anonymous> (tests/unit/public-menu.test.js:171:22)

  ● public menu page — open in Tavo app (Task 30-D) › keeps the banner hidden until the script runs, and hides it on appinstalled

    expect(received).toMatch(expected)

    Expected pattern: /id="tavo-smart-banner"[^>]*hidden/
    Received string:  "<!DOCTYPE html>
    <html lang=\"en\" dir=\"ltr\">
    <head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Burger Lab</title>
    <style>body{font-family:system-ui,sans-serif;background:#faf7f2;color:#222;margin:0}header{text-align:center;padding:32px 16px;background:#1b365d;color:#fff}.logo{width:72px;height:72px;border-radius:50%;object-fit:cover}main{max-width:640px;margin:0 auto;padding:16px}h2{border-bottom:2px solid #1b365d;padding-bottom:4px}.item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid #eee}.item-body{flex:1}.item-name{font-weight:700}.item-desc{color:#666;font-size:14px}.price{font-weight:700;white-space:nowrap}.item-img{width:64px;height:64px;border-radius:8px;object-fit:cover}</style>
    </head>
    <body><header><img class=\"logo\" src=\"/uploads/logo.png\" alt=\"\"><h1>Burger Lab</h1><p>Best burgers in Riyadh</p></header><main></main></body>
    </html>"

      180 |     const res = await request(app).get(`/menu/${SLUG}?lang=en`);
      181 |     // Hidden by default: if the script never runs the banner stays hidden.
    > 182 |     expect(res.text).toMatch(/id="tavo-smart-banner"[^>]*hidden/);
          |                      ^
      183 |     // The standard `try { appinstalled } catch` snippet.
      184 |     expect(res.text).toContain("appinstalled");
      185 |     expect(res.text).toContain("try {");

      at Object.<anonymous> (tests/unit/public-menu.test.js:182:22)

  ● public menu page — open in Tavo app (Task 30-D) › never interpolates another restaurant's slug or id

    expect(received).toContain(expected) // indexOf

    Expected substring: "/menu/burger-lab-open-app"
    Received string:    "<!DOCTYPE html>
    <html lang=\"en\" dir=\"ltr\">
    <head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Burger Lab</title>
    <style>body{font-family:system-ui,sans-serif;background:#faf7f2;color:#222;margin:0}header{text-align:center;padding:32px 16px;background:#1b365d;color:#fff}.logo{width:72px;height:72px;border-radius:50%;object-fit:cover}main{max-width:640px;margin:0 auto;padding:16px}h2{border-bottom:2px solid #1b365d;padding-bottom:4px}.item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid #eee}.item-body{flex:1}.item-name{font-weight:700}.item-desc{color:#666;font-size:14px}.price{font-weight:700;white-space:nowrap}.item-img{width:64px;height:64px;border-radius:8px;object-fit:cover}</style>
    </head>
    <body><header><img class=\"logo\" src=\"/uploads/logo.png\" alt=\"\"><h1>Burger Lab</h1><p>Best burgers in Riyadh</p></header><main></main></body>
    </html>"

      197 |
      198 |     const res = await request(app).get(`/menu/${SLUG}?lang=en`);
    > 199 |     expect(res.text).toContain(`/menu/${SLUG}`);
          |                      ^
      200 |     expect(res.text).not.toContain("sultan-fish-house");
      201 |     expect(res.text).not.toContain(`tavo://restaurant/${other._id}`);
      202 |   });

      at Object.<anonymous> (tests/unit/public-menu.test.js:199:22)

  ● public menu page — open in Tavo app (Task 30-D) › escapes a hostile slug and refuses to build an intent URL from it

    expect(received).toContain(expected) // indexOf

    Expected substring: "href=\"tavo://restaurant/6ad9ae109aed7b3b338aba71\""
    Received string:    "<!DOCTYPE html>
    <html lang=\"en\" dir=\"ltr\">
    <head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;</title>
    <style>body{font-family:system-ui,sans-serif;background:#faf7f2;color:#222;margin:0}header{text-align:center;padding:32px 16px;background:#1b365d;color:#fff}.logo{width:72px;height:72px;border-radius:50%;object-fit:cover}main{max-width:640px;margin:0 auto;padding:16px}h2{border-bottom:2px solid #1b365d;padding-bottom:4px}.item{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid #eee}.item-body{flex:1}.item-name{font-weight:700}.item-desc{color:#666;font-size:14px}.price{font-weight:700;white-space:nowrap}.item-img{width:64px;height:64px;border-radius:8px;object-fit:cover}</style>
    </head>
    <body><header><img class=\"logo\" src=\"/uploads/hostile.png\" alt=\"\"><h1>&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;</h1></header><main></main></body>
    </html>"

      219 |     expect(res.text).toContain("&lt;script&gt;alert("); // escaped, still readable
      220 |     expect(res.text).not.toContain("intent://"); // no banner from a hostile slug
    > 221 |     expect(res.text).toContain(`href="tavo://restaurant/${hostile._id}"`);
          |                      ^
      222 |   });
      223 |
      224 |   it("renders the page without a CTA when the restaurant has no _id", () => {

      at Object.<anonymous> (tests/unit/public-menu.test.js:221:22)

  ● public menu page — open in Tavo app (Task 30-D) › renders the page without a CTA when the restaurant has no _id

    TypeError: publicMenuController.renderMenu is not a function

      223 |
      224 |   it("renders the page without a CTA when the restaurant has no _id", () => {
    > 225 |     const html = publicMenuController.renderMenu(
          |                                       ^
      226 |       { en: { name: "No Id" }, ar: { name: "بدون معرف" }, slug: "no-id-restaurant" },
      227 |       [],
      228 |       [],

      at Object.<anonymous> (tests/unit/public-menu.test.js:225:39)

  ● public menu page — open in Tavo app (Task 30-D) › drops a hostile _id instead of interpolating it into the deep link

    TypeError: publicMenuController.renderMenu is not a function

      235 |
      236 |   it("drops a hostile _id instead of interpolating it into the deep link", () => {
    > 237 |     const html = publicMenuController.renderMenu(
          |                                       ^
      238 |       {
      239 |         _id: '"><script>alert(1)</script>',
      240 |         en: { name: "X" },

      at Object.<anonymous> (tests/unit/public-menu.test.js:237:39)

Test Suites: 1 failed, 1 total
Tests:       7 failed, 7 passed, 14 total
Snapshots:   0 total
Time:        1.096 s, estimated 5 s
Ran all test suites matching tests/unit/public-menu.test.js.
```

Command (GREEN, focused): `npm test -- tests/unit/public-menu.test.js`

```

> tavo@1.0.0 test
> node --experimental-vm-modules node_modules/jest/bin/jest.js tests/unit/public-menu.test.js

(node:2032) ExperimentalWarning: VM Modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)
  console.log
    Connected to in-memory test database

      at connectTestDatabase (tests/setup/testDatabase.js:25:13)

  console.log
    Disconnected from test database

      at disconnectTestDatabase (tests/setup/testDatabase.js:41:11)

Test Suites: 1 passed, 1 total
Tests:       14 passed, 14 total
Snapshots:   0 total
Time:        2.098 s
Ran all test suites matching tests/unit/public-menu.test.js.
```

Command (GREEN, full unit suite): `npm test -- tests/unit`

```
Test Suites: 51 passed, 51 total
Tests:       524 passed, 524 total
Snapshots:   0 total
Time:        34.805 s, estimated 54 s
Ran all test suites matching tests/unit.
```

The unit suite grew from Task 30-A's recorded **51 suites / 516 tests** to
**51 suites / 524 tests**: **+8 tests**, all of them Task 30-D's, added to
`tests/unit/public-menu.test.js` (the file already existed from Task 9 and was
extended, not replaced — its 6 original tests are untouched and still green).

Task 30-D's 8 assertions, in full:

- `renders an 'Open in Tavo app' CTA pointing at tavo://restaurant/<id>` — the
  CTA is present in **both** `ar` and `en`, each with its own label, and the
  Arabic label is absent from the English page (and vice versa).
- `renders the Smart Banner meta and the intent URL for THIS restaurant` —
  `<meta name="mobile-web-app-capable" content="yes">` plus the exact
  `intent://…#Intent;scheme=https;host=…;path=…;package=com.rasad.tavo;S.browser_fallback_url=…;end`.
- `keeps the banner hidden until the script runs, and hides it on appinstalled`
  — the element ships with the `hidden` attribute (so a page whose script never
  runs shows no banner) and the `try { … "appinstalled" … } catch` snippet is
  present.
- `never interpolates another restaurant's slug or id` — a second restaurant in
  the same database contributes neither its slug nor its `_id` to the page.
- `escapes a hostile slug and refuses to build an intent URL from it` — a
  restaurant whose slug is `x"><img src=x onerror=alert(1)>` and whose names are
  `<script>alert("xss")</script>` renders as escaped text, produces **no**
  `intent://` URL at all, and still gets a working CTA (the `_id` is a real
  ObjectId).
- `renders the page without a CTA when the restaurant has no _id` — the page
  still renders in full; only the CTA is absent.
- `drops a hostile _id instead of interpolating it into the deep link` — a
  `_id` of `"><script>alert(1)</script>` is dropped, not escaped.
- `does not offer the app CTA on the 404 page` — there is no restaurant to
  open, so the 404 page carries neither the CTA nor the banner.

Two notes on the test harness:

- The controller caches the rendered HTML for 60 s per `${slug}:${lang}`. Each
  test builds a **new** restaurant (a new `_id`), so Task 30-D's `beforeEach`
  calls the controller's `clearPublicMenuCache()` — otherwise the page would
  still carry the previous test's id and the assertions would be reading a
  stale document.
- `renderMenu` is now exported from `src/controllers/public-menu.controller.js`
  so the two "no `_id`" cases can be exercised on a restaurant object that the
  database can never produce (Mongo always assigns an `_id`).

`node --check src/controllers/public-menu.controller.js` → clean. The repo has
no ESLint/Prettier configuration and no `lint` script, so there is no lint step
to run.


## Task 31-B — the analytics endpoint

Files: `src/validators/analytics-panel.validator.js` (new),
`src/services/analytics-panel.services.js` (new),
`src/controllers/analytics-panel.controller.js` (new),
`src/routes/analytics-panel.route.js` (new),
`src/routes/restaurant-owner.routes.js` (mount only — 5 lines),
`tests/unit/analytics-panel.test.js` (new — 29 tests).

Endpoints (both `requirePermission("view_reports")`):

- `GET /v1/api/restaurant-owner/analytics?restaurantId=&from=&to=&range=`
- `GET /v1/api/restaurant-owner/analytics/live?restaurantId=`

### RED

The test file was written first, then the four implementation files were
removed and the panel mount reverted, so the suite ran against a tree with
no analytics code at all. Command:

```
npm test -- tests/unit/analytics-panel.test.js --runInBand
```

Result: **1 suite failed — 27 tests failed / 2 passed / 29 total.** Every
endpoint answer was `404` (the route did not exist) or an empty body.

```text
FAIL tests/unit/analytics-panel.test.js
  ● analytics endpoint (Task 31-B) › auth and validation › 403s staff without view_reports on both endpoints

    expect(received).toBe(expected) // Object.is equality

    Expected: 403
    Received: 404

      181 |       const token = viewer.generateToken();
      182 |       const res = await getAnalytics("", token);
    > 183 |       expect(res.statusCode).toBe(403);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:183:30)

  ● analytics endpoint (Task 31-B) › auth and validation › 400s an unparseable from/to and a from after to

    expect(received).toBe(expected) // Object.is equality

    Expected: 400
    Received: 404

      200 |
      201 |       const badFrom = await getAnalytics("&from=not-a-date", token);
    > 202 |       expect(badFrom.statusCode).toBe(400);
          |                                  ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:202:34)

  ● analytics endpoint (Task 31-B) › auth and validation › 400s an unknown range token and 200s every known one

    expect(received).toBe(expected) // Object.is equality

    Expected: 400
    Received: 404

      215 |       const token = owner.generateToken();
      216 |       const bad = await getAnalytics("&range=year", token);
    > 217 |       expect(bad.statusCode).toBe(400);
          |                             ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:217:30)

  ● analytics endpoint (Task 31-B) › auth and validation › returns the documented top-level shape

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      227 |     it("returns the documented top-level shape", async () => {
      228 |       const res = await getAnalytics("", owner.generateToken());
    > 229 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:229:30)

  ● analytics endpoint (Task 31-B) › revenue truth › counts only served/completed orders and keeps gross/net/tax apart

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      306 |
      307 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 308 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:308:30)

  ● analytics endpoint (Task 31-B) › revenue truth › splits gross (totalPrice) from net (subtotal) and tax

    TypeError: Cannot read properties of undefined (reading 'kpi')

      325 |
      326 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 327 |       const rev = res.body.data.kpi.revenue;
          |                                 ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:327:33)

  ● analytics endpoint (Task 31-B) › revenue truth › counts every order (any status) in kpi.orders.total and buckets by status

    TypeError: Cannot read properties of undefined (reading 'kpi')

      337 |
      338 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 339 |       const orders = res.body.data.kpi.orders;
          |                                    ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:339:36)

  ● analytics endpoint (Task 31-B) › period comparison › compares against the immediately preceding window of the same length

    TypeError: Cannot read properties of undefined (reading 'comparison')

      377 |
      378 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 379 |       const cmp = res.body.data.comparison;
          |                                 ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:379:33)

  ● analytics endpoint (Task 31-B) › period comparison › returns null (never Infinity, never a fake 100%) when previous === 0

    TypeError: Cannot read properties of undefined (reading 'comparison')

      399 |
      400 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 401 |       const cmp = res.body.data.comparison;
          |                                 ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:401:33)

  ● analytics endpoint (Task 31-B) › tenant isolation › never leaks restaurant B's ids, totals or item names into A's response

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      438 |
      439 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 440 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:440:30)

  ● analytics endpoint (Task 31-B) › tenant isolation › scopes EVERY aggregation by restaurantId inside the $match

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      461 |       try {
      462 |         const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 463 |         expect(res.statusCode).toBe(200);
          |                                ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:463:32)

  ● analytics endpoint (Task 31-B) › top items › aggregates quantity and lineTotal, sorts by revenue desc, shares sum to ~100

    TypeError: Cannot read properties of undefined (reading 'topItems')

      529 |
      530 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 531 |       const top = res.body.data.topItems;
          |                                 ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:531:33)

  ● analytics endpoint (Task 31-B) › occupancy (binding rule) › counts a table with a preparing order as occupied and a served-only table as free

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      557 |
      558 |       const res = await getLive("", owner.generateToken());
    > 559 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:559:30)

  ● analytics endpoint (Task 31-B) › occupancy (binding rule) › treats a cancelled order as free and ignores another restaurant's orders

    TypeError: Cannot read properties of undefined (reading 'occupiedTables')

      570 |
      571 |       const res = await getLive("", owner.generateToken());
    > 572 |       expect(res.body.data.occupiedTables).toBe(0);
          |                            ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:572:28)

  ● analytics endpoint (Task 31-B) › empty range › returns zeros and empty maps — never nulls

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      584 |       const emptyTo = new Date("2020-01-02T00:00:00.000Z");
      585 |       const res = await getAnalytics(`&from=${iso(emptyFrom)}&to=${iso(emptyTo)}`, owner.generateToken());
    > 586 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:586:30)

  ● analytics endpoint (Task 31-B) › lifecycle-derived metrics › reports avgPrepMinutes and avgTicketMinutes only for stamped rows

    TypeError: Cannot read properties of undefined (reading 'kpi')

      661 |
      662 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 663 |       expect(res.body.data.kpi.orders.avgPrepMinutes).toBe(20);
          |                            ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:663:28)

  ● analytics endpoint (Task 31-B) › lifecycle-derived metrics › reports null when no order carries lifecycle timestamps

    TypeError: Cannot read properties of undefined (reading 'kpi')

      669 |
      670 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 671 |       expect(res.body.data.kpi.orders.avgPrepMinutes).toBeNull();
          |                            ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:671:28)

  ● analytics endpoint (Task 31-B) › reservations › uses the snake_case `no_show` status and computes the no-show rate

    TypeError: Cannot read properties of undefined (reading 'kpi')

      686 |
      687 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 688 |       const rsv = res.body.data.kpi.reservations;
          |                                 ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:688:33)

  ● analytics endpoint (Task 31-B) › live snapshot › returns only the live object

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      704 |     it("returns only the live object", async () => {
      705 |       const res = await getLive("", owner.generateToken());
    > 706 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:706:30)

  ● analytics endpoint (Task 31-B) › live snapshot › counts today's revenue, today's orders, the open backlog and the waitlist

    TypeError: Cannot read properties of undefined (reading 'revenueToday')

      752 |
      753 |       const res = await getLive("", owner.generateToken());
      754 |       const live = res.body.data;
    > 755 |       expect(live.revenueToday).toBe(80);
          |                   ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:754:19)

  ● analytics endpoint (Task 31-B) › live snapshot › stays cheap: one batched distinct, no $unwind, no heavy range aggregation

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      770 |       try {
      771 |         const res = await getLive("", owner.generateToken());
    > 772 |         expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:772:32)

  ● analytics endpoint (Task 31-B) › alerts › raises a data-driven alert when the open-order backlog grows

    TypeError: Cannot read properties of undefined (reading 'alerts')

      803 |       }
      804 |       const res = await getAnalytics("", owner.generateToken());
    > 805 |       const alerts = res.body.data.alerts;
          |                                    ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:805:36)

  ● analytics endpoint (Task 31-B) › alerts › raises no backlog alert for a calm venue

    TypeError: Cannot read properties of undefined (reading 'alerts')

      818 |     it("raises no backlog alert for a calm venue", async () => {
      819 |       const res = await getAnalytics("", owner.generateToken());
    > 820 |       expect(res.body.data.alerts).toEqual([]);
          |                    ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:820:28)

  ● analytics endpoint (Task 31-B) › trend buckets › buckets the heatmap by weekday 0-6 (0 = Sunday) and by the local hour

    TypeError: Cannot read properties of undefined (reading 'trend')

      839 |
      840 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 841 |       const heat = res.body.data.trend.heatmap;
          |                                  ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:841:34)

  ● analytics endpoint (Task 31-B) › trend buckets › buckets the daily trend by the local calendar day

    TypeError: Cannot read properties of undefined (reading 'trend')

      862 |
      863 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 864 |       const daily = res.body.data.trend.daily;
          |                                   ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:864:35)

  ● analytics endpoint (Task 31-B) › customers › counts distinct customers and the returning ones

    TypeError: Cannot read properties of undefined (reading 'kpi')

      893 |
      894 |       const res = await getAnalytics(`&from=${iso(W_FROM)}&to=${iso(W_TO)}`, owner.generateToken());
    > 895 |       const c = res.body.data.kpi.customers;
          |                               ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:895:31)

  ● analytics endpoint (Task 31-B) › the panel mount › serves /analytics and /analytics/live through the panel router

    expect(received).toBe(expected) // Object.is equality

    Expected: 200
    Received: 404

      910 |
      911 |       const res = await getAnalytics("", owner.generateToken());
    > 912 |       expect(res.statusCode).toBe(200);
          |                              ^

      at Object.<anonymous> (tests/unit/analytics-panel.test.js:912:30)

Test Suites: 1 failed, 1 total
Tests:       27 failed, 2 passed, 29 total
Snapshots:   0 total
Time:        4.24 s
Ran all test suites matching tests/unit/analytics-panel.test.js.
```

The 2 that passed are the ones the panel router answers on its own
(`router.use(protect)` rejects an anonymous caller with 401 even for a path
that does not exist, and a foreign owner is refused with 403 by the venue
resolution the already-mounted module routers perform).

### A real bug the RED caught

The first implementation returned MongoDB's `%w` weekday verbatim. `%w` is
**1 (Sunday) … 7 (Saturday)** — NOT the 0–6 the contract asks for — so a
Thursday landed in bucket `5` instead of `4`. The bucket tests went red:

```text
  ● analytics endpoint (Task 31-B) › trend buckets › buckets the heatmap by weekday 0-6 (0 = Sunday) and by the local hour

    expect(received).toBe(expected) // Object.is equality

    Expected: 4
    Received: 5
```

and the fix was `$subtract: [{ $toInt: %w }, 1]`. (A second, related failure
— `MongoServerError: can't $subtract int from string` — taught that `$toInt`
has to wrap the `$dateToString` result *inside* the `$subtract`.)

### GREEN

Focused run — `npm test -- tests/unit/analytics-panel.test.js --runInBand`
(exit code 0):

```text
Test Suites: 1 passed, 1 total
Tests:       29 passed, 29 total
Snapshots:   0 total
Time:        3.518 s
Ran all test suites matching tests/unit/analytics-panel.test.js.
```

Full unit suite — `npm test -- tests/unit --runInBand` (exit code 0):

```text
Test Suites: 52 passed, 52 total
Tests:       553 passed, 553 total
Snapshots:   0 total
Time:        98.034 s
Ran all test suites matching tests/unit.
```

**Counts:** 52 suites / 553 tests, 0 failures. This task contributes
**1 suite / 29 tests**; the rest of the delta versus the plan baseline
(48 suites / 490 tests) is sibling Wave-2 work landing in the shared tree.

`--runInBand` was used because the parallel form of the same command is
unreliable on this machine (dozens of `mongod` instances boot at once and
suites fail with `Instance failed to start within 10000ms`).

### The contract, as implemented

- **Revenue truth** — only `orderStatus ∈ ['served','completed']` counts.
  `gross` = Σ `totalPrice`, `net` = Σ `subtotal`, `tax` = Σ `tax`, kept as
  three separate, labelled numbers. A `cancelled` or `draft` order
  contributes nothing.
- **Tenant isolation** — every query scopes the venue *inside* the query
  (`$match.restaurantId`, `$match.restaurant` for `Review`, the find/count
  filter). A test spies on `Order/Reservation/PhysicalTable/Review.aggregate`
  and asserts that **stage 0 of every pipeline** carries the requested
  venue's id. Nothing is filtered in JavaScript afterwards.
- **`deltaPct`** — `((current − previous) / previous) × 100`, and **null**
  when `previous === 0`. Never `Infinity`, never a fake 100 %.
- **Occupancy** — the binding rule (spec Decision 5), byte-for-byte the same
  filter Task 28 uses on `GET /tables/:tableTypeId/physical`:
  `orderStatus: { $nin: ['served','cancelled'] }`. A `preparing` order
  occupies its table; a `served`/`cancelled` order does not.
- **`avgPrepMinutes` / `avgTicketMinutes`** — computed **only** from rows
  that carry a real lifecycle stamp (`acceptedAt` + `readyAt` /
  `acceptedAt` + `servedAt`). Rows without a stamp are skipped, never
  counted as zero, and the API reports `null` when no row qualifies.
- **Empty range** — every numeric is `0` and every map is `{}`
  (`orders.byStatus`, `reservations.byStatus`), `range.days` is still
  populated. The three values the spec itself names as nullable
  (`comparison.*.deltaPct`, `kpi.orders.avgPrepMinutes`,
  `kpi.avgTicketMinutes`) stay `null` — they are the spec's explicit
  exception to "zeros, not nulls".
- **The poll stays cheap** — `getLiveSnapshot` runs six `countDocuments`,
  one `find`, exactly **one** `Order.distinct` (the batched occupancy rule)
  and **one** small `$facet` aggregation. No `$unwind`, no range scan. A test
  spies on `Order.aggregate` / `Order.distinct` and asserts the distinct
  count is `1`, its filter is the binding rule, and that no pipeline
  unwinds.
- **`no_show`** — the reservation enum's own value (snake_case) is what
  `kpi.reservations.byStatus` uses. The Dart model reads `noShow`; the
  mapping is the app's job, and the report says so explicitly.
- **`comparison.previous`** — the immediately preceding window of the same
  length: `previous.to = from − 1 ms`, `previous.from = previous.to − (to − from)`.

The complete sample JSON response (the one the Flutter task builds its models
from) is in
`.superpowers/sdd/2026-10-22-restaurant-intelligence-wave2/task-31-b-report.md`.

## Task 32 — the dashboard rebuild

### RED — the new test file, before a single line of the module existed

`flutter test test/panel_dashboard_v2_test.dart`

The test file was written first (26 cases: the models, the repo, the cubit
and every widget). It could not even COMPILE: the analytics module —
`analytics_models.dart`, `analytics_panel_repo.dart`, the cubit, the state
and the twelve widgets — did not exist. (The output below is the real run;
the implementation files were moved out of the tree to reproduce it
byte-for-byte. The full output is 512 lines — the middle is elided.)

```
00:00 +0: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_dashboard_v2_test.dart
test/panel_dashboard_v2_test.dart:21:8: Error: Error when reading 'lib/feature/panel_dashboard/data/repo/analytics_panel_repo.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
       ^
test/panel_dashboard_v2_test.dart:22:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/logic/dashboard_cubit.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';
       ^
test/panel_dashboard_v2_test.dart:23:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/alert_rail.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/alert_rail.dart';
       ^
test/panel_dashboard_v2_test.dart:24:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/comparison_row.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/comparison_row.dart';
       ^
test/panel_dashboard_v2_test.dart:25:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/date_range_selector.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/date_range_selector.dart';
       ^
test/panel_dashboard_v2_test.dart:26:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/kpi_tiles.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/kpi_tiles.dart';
       ^
test/panel_dashboard_v2_test.dart:27:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/live_hero_band.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/live_hero_band.dart';
       ^
test/panel_dashboard_v2_test.dart:28:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/management_shortcuts.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/management_shortcuts.dart';
       ^
test/panel_dashboard_v2_test.dart:29:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/occupancy_ring.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/occupancy_ring.dart';
       ^
test/panel_dashboard_v2_test.dart:30:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/order_pipeline.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/order_pipeline.dart';
       ^
test/panel_dashboard_v2_test.dart:31:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/orders_volume_chart.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/orders_volume_chart.dart';
       ^
test/panel_dashboard_v2_test.dart:32:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/peak_hours_heatmap.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/peak_hours_heatmap.dart';
       ^
test/panel_dashboard_v2_test.dart:33:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart';
       ^
test/panel_dashboard_v2_test.dart:34:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/section_error_boundary.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/section_error_boundary.dart';
       ^
test/panel_dashboard_v2_test.dart:35:8: Error: Error when reading 'lib/feature/panel_dashboard/ui/widgets/top_items_chart.dart': No such file or directory
import 'package:tavo/feature/panel_dashboard/ui/widgets/top_items_chart.dart';
       ^
test/panel_dashboard_v2_test.dart:158:34: Error: Type 'AnalyticsPanelRepo' not found.
class _FakeAnalyticsRepo extends AnalyticsPanelRepo {
                                 ^^^^^^^^^^^^^^^^^^
test/panel_dashboard_v2_test.dart:161:3: Error: Type 'DashboardAnalytics' not found.
  DashboardAnalytics analytics = DashboardAnalytics.fromJson(sampleAnalytics);
  ^^^^^^^^^^^^^^^^^^
  [... 446 further compile errors elided — the whole analytics module did not exist yet ...]
  test/panel_dashboard_v2_test.dart:726:25: Error: Undefined name 'DashboardAnalytics'.
        final analytics = DashboardAnalytics.fromJson(sampleAnalytics);
                          ^^^^^^^^^^^^^^^^^^
  test/panel_dashboard_v2_test.dart:735:19: Error: Method not found: 'PeakHoursHeatmap'.
                    PeakHoursHeatmap(cells: analytics.trend.heatmap),
                    ^^^^^^^^^^^^^^^^
  test/panel_dashboard_v2_test.dart:736:19: Error: Method not found: 'TopItemsChart'.
                    TopItemsChart(items: analytics.topItems),
                    ^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/elmarakbeno/development/tavo/tavo-app/test/panel_dashboard_v2_test.dart: loading /Users/elmarakbeno/development/tavo/tavo-app/test/panel_dashboard_v2_test.dart
```

### GREEN — focused

`flutter test test/panel_dashboard_v2_test.dart`

```
00:01 +26: widgets RTL flips the heatmap hours and the bar order
00:01 +26: (tearDownAll)
00:01 +26: All tests passed!
```

### GREEN — the dashboard module's own suites

`flutter test test/panel_dashboard_v2_test.dart test/panel_dashboard_test.dart test/dashboard_screen_widget_test.dart`

```
00:01 +39: (tearDownAll)
00:01 +39: All tests passed!
```

### GREEN — full suite

`flutter test`

```
00:31 +289: /Users/elmarakbeno/development/tavo/tavo-app/test/panel_tables_redesign_test.dart: (tearDownAll)
00:31 +289: All tests passed!
```

Baseline before this task: **240 passed, 0 failed**. After: **289 passed, 0
failed** (the old dashboard suites were rewritten, not deleted — see the
report).

### `flutter analyze`

Before: **25 issues**. After: **25 issues** — no new issue, no new
deprecation.

## Task 33-B — motion adoption across both app surfaces

_(pending)_

## Task 34 — verification, live deploy, QR proof

_(pending)_
