// lib/core/animation/motion_tokens.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The duration tokens of the app's motion system.
///
/// Every animation in the app picks its duration from this list so the
/// product feels like one thing instead of a pile of hand-picked numbers.
class AppDurations {
  /// Press feedback and other micro-interactions (150 ms).
  static const Duration fast = Duration(milliseconds: 150);

  /// The default duration for most transitions (250 ms).
  static const Duration normal = Duration(milliseconds: 250);

  /// Entrances and exits that carry more weight (400 ms).
  static const Duration slow = Duration(milliseconds: 400);

  /// Hero transitions that carry the eye across the app (500 ms).
  static const Duration hero = Duration(milliseconds: 500);
}

/// The curve tokens of the app's motion system.
///
/// Curves are only used where a spring does not fit (progress bars, colour
/// cross-fades). Spring-driven motion never uses `Curves.elasticOut`: data
/// tiles and charts must not overshoot.
class AppCurves {
  /// The standard decelerating curve.
  static const Cubic easeOut = Curves.easeOutCubic;

  /// The standard accelerating curve.
  static const Cubic easeIn = Curves.easeInCubic;

  /// The emphasized curve used for hero transitions.
  static const Cubic emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}

/// The spring tokens of the app's motion system.
///
/// A spring is described by its mass, stiffness and damping. The damping
/// ratio decides whether it overshoots: below `1.0` it bounces, at `1.0` it
/// is critically damped.
class AppSprings {
  /// Press feedback: fast and almost critically damped.
  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 30,
  );

  /// Entrances and reveals: soft, with a barely visible bounce.
  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 24,
  );

  /// Playful, customer-facing moments: clearly visible overshoot.
  ///
  /// Never use this spring for data tiles or charts.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 16,
  );

  /// The spring handed out when the platform asks for reduced motion.
  ///
  /// Flutter does not ship a `SpringDescription.noSpring`, so the app
  /// provides its own: critically damped and stiff enough to resolve within
  /// a couple of frames, and it never overshoots.
  static const SpringDescription noSpring = SpringDescription(
    mass: 1,
    stiffness: 10000,
    damping: 200,
  );

  /// The tolerance every spring simulation in the app runs with.
  ///
  /// The default tolerance of `1e-3` is far too tight for a KPI that animates
  /// from `0` to `1250`: the spring would need more than a second of real time
  /// to fall under it and the animation would never look finished. The
  /// tolerance therefore scales with the distance the spring travels, which
  /// keeps the settle time roughly constant no matter the magnitude.
  static Tolerance toleranceFor(double span) {
    final double distance = span.abs();
    return Tolerance(
      distance: math.max(0.001, distance * 0.001),
      velocity: math.max(0.001, distance * 0.05),
    );
  }
}
