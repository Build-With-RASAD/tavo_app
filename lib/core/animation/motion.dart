// lib/core/animation/motion.dart

import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Reduced-motion aware helpers shared by every animated widget.
///
/// The platform can ask the app to stop animating (the iOS "Reduce Motion"
/// switch, the Android "Remove animations" developer option). When it does,
/// every animation in the app collapses to its final frame instead of
/// disappearing — the user still sees the change, they just do not see it
/// move.
class Motion {
  /// Whether the platform asked for reduced motion.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [full], unless motion is reduced, in which case the animation collapses
  /// to its final frame.
  static Duration adapt(BuildContext context, Duration full) =>
      isReduced(context) ? Duration.zero : full;

  /// [spring], unless motion is reduced, in which case the no-motion spring
  /// is returned.
  static SpringDescription springFor(
    BuildContext context,
    SpringDescription spring,
  ) =>
      isReduced(context) ? AppSprings.noSpring : spring;
}
