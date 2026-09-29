// integration_test/e2e_helpers.dart
//
// Shared harness for the full-app-flow E2E suite. Ground rules:
//
//  * NEVER pumpAndSettle: the home shimmer, PromoBanner's 4s ticker, the OTP
//    1s countdown and modal-sheet spinners never become idle.
//  * pumpUntil()/pumpUntilGone() poll on the REAL clock with bounded pumps.
//  * app.main() calls initServiceLocator(), which registers everything into
//    GetIt — a fresh getIt.reset() is required before every launch or the
//    second launch throws "Object already registered".
//  * easy_localization persists the app locale under the plain 'locale' key;
//    seed it before app.main() so assertions run against en.json copy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tavo/main.dart' as app;

/// Deliberately invalid bearer token. Protected endpoints answer
/// 401 {"status":"error","message":"Invalid token"} without touching any real
/// user data, so the authed flow can exercise the full navigation surface.
const String kInvalidToken = 'e2e-invalid-token';

// The backend's aggregate endpoints are cold-cache slow: /v1/api/home
// measured 15-25s cold (0.4s warm) with erratic TCP connects, so data pumps
// need a 60s budget rather than 30s.
const Duration kDefaultTimeout = Duration(seconds: 60);

/// Snapshot of onstage text, appended to timeout failures so a red run is
/// self-explaining (empty state vs error widget vs still-loading shimmer).
String _visibleTextDump() {
  try {
    final texts = find.byType(Text).evaluate().map((e) {
      final w = e.widget;
      if (w is Text) {
        final d = w.data ?? w.textSpan?.toPlainText();
        if (d != null && d.trim().isNotEmpty) return d.trim();
      }
      return null;
    }).whereType<String>().toSet().toList();
    return 'onstage texts: ${texts.take(40)}';
  } catch (e) {
    return '(text dump failed: $e)';
  }
}

/// Whether [finder] currently matches. `.first`/`.last` finders throw
/// StateError from their filter when the parent chain matches zero widgets
/// (flutter_test `_FirstFinderMixin.filter`: `yield parentCandidates.first`),
/// which during polling just means "not there yet" — map it to false.
bool _hasMatch(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

/// Polls until [finder] matches at least one widget, pumping every 100ms.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = kDefaultTimeout,
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_hasMatch(finder)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for '
    '${reason ?? finder.toString()} | ${_visibleTextDump()}',
  );
}

/// Polls until [finder] matches nothing (route popped, sheet dismissed, …).
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = kDefaultTimeout,
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!_hasMatch(finder)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
  fail(
    'Timed out after ${timeout.inSeconds}s waiting for '
    '${reason ?? finder.toString()} to disappear | ${_visibleTextDump()}',
  );
}

/// Lets real time pass so page/route transitions finish before the next
/// finder runs — avoids transient duplicate matches mid-animation (e.g. two
/// onboarding pages mounted at once during a page transition).
Future<void> settle(WidgetTester tester, [int ms = 700]) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump();
}

/// Launches the app with deterministic prefs.
///
/// * fresh (`authenticated: false`): prefs cleared, locale `en` only —
///   splash must route to onboarding.
/// * authed (`authenticated: true`): invalid token + onboarding flag set —
///   splash must route to [MainNavScreen].
Future<void> launchApp(
  WidgetTester tester, {
  required bool authenticated,
}) async {
  await GetIt.I.reset();

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setString('locale', 'en');
  if (authenticated) {
    await prefs.setString('token', kInvalidToken);
    await prefs.setBool('onboarding_completed', true);
  }

  // main() is `async void` (not awaitable): callers poll with pumpUntil()
  // for SplashScreen instead of awaiting it.
  app.main();
  await tester.pump();
}
