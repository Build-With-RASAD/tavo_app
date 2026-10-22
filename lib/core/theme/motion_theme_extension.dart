// lib/core/theme/motion_theme_extension.dart

import 'package:flutter/material.dart';

import '../animation/motion_tokens.dart';

/// The motion tokens of a [ThemeData].
///
/// Register it through `ThemeData.extensions` to override the springs and
/// durations the app uses:
///
/// ```dart
/// ThemeData(
///   extensions: const <ThemeExtension<dynamic>>[
///     MotionTheme(revealSpring: AppSprings.bouncy),
///   ],
/// )
/// ```
@immutable
class MotionTheme extends ThemeExtension<MotionTheme> {
  /// Creates a set of motion tokens. Every token falls back to the app
  /// default.
  const MotionTheme({
    this.pressSpring = AppSprings.snappy,
    this.revealSpring = AppSprings.gentle,
    this.counterSpring = AppSprings.gentle,
    this.sheetSpring = AppSprings.gentle,
    this.fastDuration = AppDurations.fast,
    this.normalDuration = AppDurations.normal,
    this.slowDuration = AppDurations.slow,
    this.heroDuration = AppDurations.hero,
  });

  /// The spring used for press feedback.
  final SpringDescription pressSpring;

  /// The spring used for staggered entrances.
  final SpringDescription revealSpring;

  /// The spring used for numeric counters.
  final SpringDescription counterSpring;

  /// The spring used for sheet and dialog entrances.
  final SpringDescription sheetSpring;

  /// The duration used for press feedback.
  final Duration fastDuration;

  /// The duration used for most transitions.
  final Duration normalDuration;

  /// The duration used for weighted entrances and exits.
  final Duration slowDuration;

  /// The duration used for hero transitions.
  final Duration heroDuration;

  /// The motion tokens of the closest [ThemeData], or the app defaults when
  /// the theme does not register a [MotionTheme].
  static MotionTheme of(BuildContext context) =>
      Theme.of(context).extension<MotionTheme>() ?? const MotionTheme();

  @override
  MotionTheme copyWith({
    SpringDescription? pressSpring,
    SpringDescription? revealSpring,
    SpringDescription? counterSpring,
    SpringDescription? sheetSpring,
    Duration? fastDuration,
    Duration? normalDuration,
    Duration? slowDuration,
    Duration? heroDuration,
  }) {
    return MotionTheme(
      pressSpring: pressSpring ?? this.pressSpring,
      revealSpring: revealSpring ?? this.revealSpring,
      counterSpring: counterSpring ?? this.counterSpring,
      sheetSpring: sheetSpring ?? this.sheetSpring,
      fastDuration: fastDuration ?? this.fastDuration,
      normalDuration: normalDuration ?? this.normalDuration,
      slowDuration: slowDuration ?? this.slowDuration,
      heroDuration: heroDuration ?? this.heroDuration,
    );
  }

  @override
  MotionTheme lerp(covariant MotionTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return MotionTheme(
      pressSpring: _lerpSpring(pressSpring, other.pressSpring, t),
      revealSpring: _lerpSpring(revealSpring, other.revealSpring, t),
      counterSpring: _lerpSpring(counterSpring, other.counterSpring, t),
      sheetSpring: _lerpSpring(sheetSpring, other.sheetSpring, t),
      fastDuration: _lerpDuration(fastDuration, other.fastDuration, t),
      normalDuration: _lerpDuration(normalDuration, other.normalDuration, t),
      slowDuration: _lerpDuration(slowDuration, other.slowDuration, t),
      heroDuration: _lerpDuration(heroDuration, other.heroDuration, t),
    );
  }

  static SpringDescription _lerpSpring(
    SpringDescription a,
    SpringDescription b,
    double t,
  ) {
    return SpringDescription(
      mass: _lerpDouble(a.mass, b.mass, t),
      stiffness: _lerpDouble(a.stiffness, b.stiffness, t),
      damping: _lerpDouble(a.damping, b.damping, t),
    );
  }

  static Duration _lerpDuration(Duration a, Duration b, double t) {
    return Duration(
      microseconds: _lerpDouble(
        a.inMicroseconds.toDouble(),
        b.inMicroseconds.toDouble(),
        t,
      ).round(),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    if (t < 0) {
      return a;
    }
    if (t > 1) {
      return b;
    }
    return a + (b - a) * t;
  }
}
