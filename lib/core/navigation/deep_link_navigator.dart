// lib/core/navigation/deep_link_navigator.dart
import 'package:flutter/material.dart';
import 'package:tavo/core/navigation/deep_link_target.dart';

/// Routes deep-link targets into the app once the app is ready to show them.
///
/// **Why the buffering exists.** The splash screen deliberately waits three
/// seconds before replacing itself with the app's first real screen. A link
/// that launched the app resolves long before that — the slug lookup is a
/// single HTTP call. Pushing the target during the splash would put the
/// restaurant screen *under* the splash's own `pushReplacement`, which would
/// then replace it and silently throw the destination away.
///
/// So a target that arrives before the app is ready is held, and flushed the
/// moment the splash hands over the navigator.
class DeepLinkNavigator extends NavigatorObserver {
  DeepLinkNavigator({required this.onTarget, required this.onUnresolved});

  /// Called with a target that is ready to be shown.
  final void Function(DeepLinkTarget target) onTarget;

  /// Called once the app is ready but the link could not be acted on, so the
  /// user gets an explanation instead of silence.
  final void Function() onUnresolved;

  bool _ready = false;
  DeepLinkTarget? _pendingTarget;
  bool _pendingUnresolved = false;

  /// Whether the app has handed over the navigator yet.
  bool get isReady => _ready;

  /// Offers a target to the app. Buffers it until the app is ready.
  void offer(DeepLinkTarget target) {
    if (!_ready) {
      _pendingTarget = target;
      return;
    }
    onTarget(target);
  }

  /// Reports that a link arrived but could not be acted on.
  void reportUnresolved() {
    if (!_ready) {
      _pendingUnresolved = true;
      return;
    }
    onUnresolved();
  }

  /// Marks the app as ready and flushes anything that was buffered.
  ///
  /// Safe to call more than once — only the first call flushes.
  void markReady() {
    if (_ready) return;
    _ready = true;

    final target = _pendingTarget;
    final unresolved = _pendingUnresolved;
    _pendingTarget = null;
    _pendingUnresolved = false;

    if (target != null) {
      onTarget(target);
    } else if (unresolved) {
      onUnresolved();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_ready) return;
    // The splash replaces itself with the app's first real screen. The
    // navigator is being mutated during this callback, so the flush is
    // deferred to the end of the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => markReady());
  }
}
