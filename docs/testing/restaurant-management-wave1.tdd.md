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
