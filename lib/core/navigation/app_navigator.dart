// lib/core/navigation/app_navigator.dart
import 'package:flutter/material.dart';

/// The app's root navigator key.
///
/// It lives here rather than in `main.dart` so both the app root (which
/// routes deep links) and the staff shell (which closes a pushed hub screen
/// before switching tabs) reach the same navigator.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Pops the top route when there is one to pop.
///
/// Returns `false` when there is nothing to pop. The root route is not
/// poppable, so a caller that blindly popped would close the app instead of
/// doing nothing — this makes the "close the pushed screen, then switch tab"
/// pattern safe to run from a callback that may fire in either context.
bool popIfPossible() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || !navigator.canPop()) return false;
  navigator.pop();
  return true;
}
