// lib/core/animation/primitives/spring_press.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../../theme/motion_theme_extension.dart';
import '../motion.dart';
import '../motion_tokens.dart';

/// Wraps [child] with a spring-driven press feedback.
///
/// The child scales down to [scale] while it is held and springs back when
/// the finger lifts. Only the transform is animated — never a layout
/// property — so a press inside a scrolling list stays on the compositor.
///
/// Under reduced motion the widget is a no-op: the child keeps the identity
/// transform for the whole gesture.
class SpringPress extends StatefulWidget {
  /// Creates a press-feedback wrapper around [child].
  const SpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.spring,
    this.enabled = true,
  });

  /// The widget the press feedback is applied to.
  final Widget child;

  /// Called when the child is tapped.
  final VoidCallback? onTap;

  /// Called when the child is long-pressed.
  final VoidCallback? onLongPress;

  /// The scale the child shrinks to while it is held.
  final double scale;

  /// Overrides the press spring of the [MotionTheme].
  final SpringDescription? spring;

  /// Whether the press feedback is active.
  final bool enabled;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.isReduced(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _springTo(1.0);
  }

  void _handleTapUp(TapUpDetails details) {
    _springTo(0.0);
  }

  void _handleTapCancel() {
    _springTo(0.0);
  }

  void _springTo(double target) {
    if (_reduced || !widget.enabled) {
      return;
    }
    final double from = _controller.value;
    if (from == target) {
      return;
    }
    final SpringDescription spring = Motion.springFor(
      context,
      widget.spring ?? MotionTheme.of(context).pressSpring,
    );
    _controller.animateWith(
      SpringSimulation(
        spring,
        from,
        target,
        0.0,
        snapToEnd: true,
        tolerance: AppSprings.toleranceFor(target - from),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: widget.enabled ? _handleTapDown : null,
      onTapUp: widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double press = _reduced ? 0.0 : _controller.value;
          final double scale = 1.0 - (1.0 - widget.scale) * press;
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
