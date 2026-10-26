// lib/core/ui/tavo_web/tavo_motion.dart
//
// Motion primitives that reproduce the website's behaviour in Flutter:
//
//   reveal        opacity 0→1 + y 12→0, 400 ms, power3.out (easeOutQuart)
//   stagger       30 ms per item, capped at 8 (site: 50–100 ms per card)
//   press         active:scale-[0.98], 150 ms
//   switch        enter 220 ms ease-out, exit 220 ms ease-in
//
// Everything honours `MediaQuery.disableAnimationsOf`, which is the same
// signal the rest of the app uses (`Motion.isReduced`). In reduced mode the
// primitives return the child untouched — no `Opacity`, no transform — so a
// screen reader never sees a half-faded element and tests can assert the
// absence of animation widgets.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tavo_tokens.dart';

/// Fade + rise entrance. Use [index] to stagger a list without writing a
/// timeline in the screen.
///
/// ```dart
/// ListView(
///   children: [
///     for (var i = 0; i < items.length; i++)
///       TavoReveal(index: i, child: TavoCard(child: ...)),
///   ],
/// )
/// ```
class TavoReveal extends StatefulWidget {
  /// Creates a reveal.
  const TavoReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = TavoMotion.reveal,
    this.offset = 12,
    this.curve = TavoMotion.outStrong,
  });

  /// Content to reveal.
  final Widget child;

  /// Position in a list. The delay is `30 ms × min(index, 8)`.
  final int index;

  /// Tween length. Defaults to the GSAP `0.4` token.
  final Duration duration;

  /// Vertical travel in logical pixels.
  final double offset;

  /// GSAP `power3.out` by default.
  final Curve curve;

  @override
  State<TavoReveal> createState() => _TavoRevealState();
}

class _TavoRevealState extends State<TavoReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  Timer? _delay;
  bool _scheduled = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (reduced) {
        _delay?.cancel();
        _controller.value = 1;
        return;
      }
      _controller.value = 0;
      _scheduled = false;
    }

    if (_reduced || _scheduled) return;
    _scheduled = true;

    final int capped = math.min(widget.index, TavoMotion.maxStaggerItems);
    final Duration delay = TavoMotion.stagger * capped;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted && !_reduced) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// `active:scale-[0.98]` without stealing the gesture.
///
/// A [Listener] observes the pointer; the gesture arena is untouched, so an
/// `InkWell`, `GestureDetector` or `Dismissible` inside still receives the
/// tap. Colour changes remain the child's job.
class TavoPressScale extends StatefulWidget {
  /// Creates a press-scale wrapper.
  const TavoPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = TavoMotion.pressScale,
    this.duration = TavoMotion.fast,
  });

  /// The interactive child.
  final Widget child;

  /// Set to `false` for a disabled control.
  final bool enabled;

  /// Scale while held. The site uses 0.98.
  final double scale;

  /// Scale-down/up duration.
  final Duration duration;

  @override
  State<TavoPressScale> createState() => _TavoPressScaleState();
}

class _TavoPressScaleState extends State<TavoPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: widget.duration,
        curve: TavoMotion.out,
        child: widget.child,
      ),
    );
  }
}

/// `AnimatedSwitcher` with the site's curves and reduced-motion bypass.
///
/// Give the child a changing [Key] to trigger the transition.
class TavoAnimatedSwitcher extends StatelessWidget {
  /// Creates a switcher.
  const TavoAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = TavoMotion.base,
    this.switchInCurve = TavoMotion.outStrong,
    this.switchOutCurve = TavoMotion.inCubic,
    this.layoutBuilder,
  });

  /// The current child. Key it when the content changes.
  final Widget child;

  /// Half of the cross-fade length.
  final Duration duration;

  /// Enter curve — GSAP `power3.out`.
  final Curve switchInCurve;

  /// Exit curve — GSAP `power2.in`.
  final Curve switchOutCurve;

  /// Forwarded to [AnimatedSwitcher].
  final AnimatedSwitcherLayoutBuilder? layoutBuilder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: layoutBuilder ?? AnimatedSwitcher.defaultLayoutBuilder,
      child: child,
    );
  }
}
