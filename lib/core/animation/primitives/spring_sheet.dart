// lib/core/animation/primitives/spring_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../../theme/motion_theme_extension.dart';
import '../motion.dart';
import '../motion_tokens.dart';

/// Drives the entrance of a sheet or a dialog on a spring.
///
/// The child slides in from [beginOffset] while it grows from [beginScale] to
/// its natural size and fades in. Only the transform and the opacity are
/// animated — never a layout property — so the sheet can be laid out once
/// and still move on the compositor.
///
/// Under reduced motion the sheet is shown at its final transform straight
/// away.
class SpringSheet extends StatefulWidget {
  /// Creates a spring-driven entrance for [child].
  const SpringSheet({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 0.12),
    this.beginScale = 0.96,
    this.spring,
  });

  /// The sheet or dialog content.
  final Widget child;

  /// Where the sheet starts from, as a fraction of its own size.
  final Offset beginOffset;

  /// The scale the sheet starts from.
  final double beginScale;

  /// Overrides the sheet spring of the [MotionTheme].
  final SpringDescription? spring;

  @override
  State<SpringSheet> createState() => _SpringSheetState();
}

class _SpringSheetState extends State<SpringSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduced = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.isReduced(context);
    if (_started) {
      return;
    }
    _started = true;
    if (_reduced) {
      return;
    }
    final SpringDescription spring = Motion.springFor(
      context,
      widget.spring ?? MotionTheme.of(context).sheetSpring,
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double progress = _reduced ? 1.0 : _controller.value;
        final double scale =
            widget.beginScale + (1.0 - widget.beginScale) * progress;
        final Offset offset = widget.beginOffset * (1.0 - progress);
        final Matrix4 matrix = Matrix4.identity()
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..setEntry(0, 3, offset.dx)
          ..setEntry(1, 3, offset.dy);
        return Transform(
          transform: matrix,
          child: Opacity(
            opacity: progress.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
