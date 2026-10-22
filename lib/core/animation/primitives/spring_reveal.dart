// lib/core/animation/primitives/spring_reveal.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../../theme/motion_theme_extension.dart';
import '../motion.dart';
import '../motion_tokens.dart';

/// Reveals a list of children one after the other.
///
/// Child *n* starts [itemDelay] later than child *n-1*, so a list of KPI tiles
/// arrives as a sequence instead of a single flash. Each child fades and
/// slides in on a spring.
///
/// Only the opacity and the transform of a child are animated — never a
/// layout property. Under reduced motion every child is shown immediately,
/// without the stagger.
class SpringReveal extends StatelessWidget {
  /// Creates a staggered entrance for [children].
  const SpringReveal({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.beginOffset = const Offset(0, 0.08),
    this.spring,
  });

  /// The children to reveal, in order.
  final List<Widget> children;

  /// The delay between two consecutive children.
  final Duration itemDelay;

  /// Where a child starts from, as a fraction of its own size.
  final Offset beginOffset;

  /// Overrides the reveal spring of the [MotionTheme].
  final SpringDescription? spring;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(children.length, (int index) {
        return _SpringRevealItem(
          delay: itemDelay * index,
          beginOffset: beginOffset,
          spring: spring,
          child: children[index],
        );
      }),
    );
  }
}

class _SpringRevealItem extends StatefulWidget {
  const _SpringRevealItem({
    required this.child,
    required this.delay,
    required this.beginOffset,
    this.spring,
  });

  final Widget child;
  final Duration delay;
  final Offset beginOffset;
  final SpringDescription? spring;

  @override
  State<_SpringRevealItem> createState() => _SpringRevealItemState();
}

class _SpringRevealItemState extends State<_SpringRevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(_controller);
    _timer = Timer(widget.delay, _start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = Motion.isReduced(context);
    if (reduced == _reduced) {
      return;
    }
    _reduced = reduced;
    if (reduced) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer == null && !_controller.isAnimating) {
      _timer = Timer(widget.delay, _start);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer = null;
    if (_reduced || !mounted) {
      return;
    }
    final SpringDescription spring = Motion.springFor(
      context,
      widget.spring ?? MotionTheme.of(context).revealSpring,
    );
    _controller.animateWith(
      SpringSimulation(
        spring,
        0.0,
        1.0,
        0.0,
        snapToEnd: true,
        tolerance: AppSprings.toleranceFor(1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> fade = _reduced
        ? const AlwaysStoppedAnimation<double>(1.0)
        : _controller;
    final Animation<Offset> slide = _reduced
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : _slide;
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
