// lib/core/animation/primitives/spring_counter.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../../theme/motion_theme_extension.dart';
import '../motion.dart';
import '../motion_tokens.dart';

/// Animates a number towards its target on a spring.
///
/// Used for the KPI numbers of the dashboard: the tile reports the live
/// value, the counter springs from the previous value towards the new one so
/// the change is noticed without the number ever lying about where it is.
///
/// Under reduced motion the counter jumps straight to the target.
class SpringCounter extends StatefulWidget {
  /// Creates a counter that animates towards [value].
  const SpringCounter({
    super.key,
    required this.value,
    required this.builder,
    this.from = 0.0,
    this.spring,
  });

  /// The value the counter animates towards.
  final double value;

  /// The value the counter starts from on its first frame.
  final double from;

  /// Builds the widget for the current value.
  final Widget Function(BuildContext context, double value) builder;

  /// Overrides the counter spring of the [MotionTheme].
  final SpringDescription? spring;

  @override
  State<SpringCounter> createState() => _SpringCounterState();
}

class _SpringCounterState extends State<SpringCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduced = false;
  bool _started = false;
  bool _built = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: widget.from);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.isReduced(context);
    if (!_started) {
      _started = true;
      _animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(SpringCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animateTo(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The value the counter renders right now.
  double get _displayValue => _reduced ? widget.value : _controller.value;

  void _animateTo(double target) {
    if (_reduced) {
      _syncController(target);
      return;
    }
    final double from = _controller.value;
    if (from == target) {
      return;
    }
    final SpringDescription spring = Motion.springFor(
      context,
      widget.spring ?? MotionTheme.of(context).counterSpring,
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

  /// Moves the controller to [target] without notifying its listeners while
  /// the widget tree is being built.
  void _syncController(double target) {
    if (_controller.value == target) {
      return;
    }
    if (_built) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          _controller.value = target;
        }
      });
      return;
    }
    _controller.value = target;
  }

  @override
  Widget build(BuildContext context) {
    _built = true;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) =>
          widget.builder(context, _displayValue),
    );
  }
}
