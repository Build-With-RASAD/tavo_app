// lib/core/ui/tavo_web/tavo_sheet.dart
//
// Bottom-sheet shell for the panel. The app currently calls
// `showModalBottomSheet` directly in several screens, which gives every
// sheet a different radius, barrier and drag behaviour. This is the single
// shell instead:
//
//   surface      #FFFFFF, 32 px top radius, shadow-2xl
//   barrier      #111111 at 50% (site `bg-foreground/50`)
//   handle       40 × 4, #D9D9D9, 24 px drag strip
//   dismissal    drag > 96 px or velocity > 700 px/s; drag back under 220 ms
//
// The drag gesture wraps the whole surface and defers to inner scrollables:
// a `ListView` in the body keeps its own scroll, and the sheet drags from the
// handle, the header and any non-scrollable area.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tavo_tokens.dart';

/// A bottom sheet with a drag-to-dismiss shell.
class TavoSheet extends StatefulWidget {
  /// Creates a sheet shell. Prefer [TavoSheet.show] to present it.
  const TavoSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.showHandle = true,
    this.maxHeightFactor = 0.92,
    this.maxWidth = 640,
    this.dismissThreshold = 96,
    this.dismissVelocity = 700,
    this.backgroundColor,
    this.onDismiss,
  });

  /// Key on the drag handle — stable anchor for tests and tooltips.
  static const ValueKey<String> handleKey = ValueKey<String>(
    'tavo_sheet_handle',
  );

  /// Presents a [TavoSheet] as a modal route.
  ///
  /// ```dart
  /// final bool? confirmed = await TavoSheet.show<bool>(
  ///   context,
  ///   title: t('cancel_order'),
  ///   child: CancelOrderBody(),
  /// );
  /// ```
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    String? subtitle,
    bool isDismissible = true,
    bool useRootNavigator = false,
    double maxHeightFactor = 0.92,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: TavoColors.overlay,
      builder: (BuildContext context) => TavoSheet(
        title: title,
        subtitle: subtitle,
        maxHeightFactor: maxHeightFactor,
        backgroundColor: backgroundColor,
        child: child,
      ),
    );
  }

  /// Sheet content. It receives a bounded max height; make long content
  /// scroll (`shrinkWrap: true` for an inner `ListView`).
  final Widget child;

  /// Optional heading, already localised.
  final String? title;

  /// Optional supporting line under [title].
  final String? subtitle;

  /// Whether to paint the 40 × 4 grab handle.
  final bool showHandle;

  /// Fraction of the screen the sheet may occupy.
  final double maxHeightFactor;

  /// Width cap on tablets and desktop.
  final double maxWidth;

  /// Downward travel that dismisses on release.
  final double dismissThreshold;

  /// Downward velocity (px/s) that dismisses regardless of travel.
  final double dismissVelocity;

  /// Overrides the white surface.
  final Color? backgroundColor;

  /// Called instead of popping when the sheet is used inline. When `null`
  /// the nearest modal route is popped.
  final VoidCallback? onDismiss;

  @override
  State<TavoSheet> createState() => _TavoSheetState();
}

class _TavoSheetState extends State<TavoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: TavoMotion.base,
  );

  double _drag = 0;
  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final double t = Curves.easeOutCubic.transform(_settle.value);
      setState(() => _drag = _settleFrom * (1 - t));
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return;
    }
    NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_settle.isAnimating) _settle.stop();
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (_drag > widget.dismissThreshold || velocity > widget.dismissVelocity) {
      _dismiss();
      return;
    }
    if (_drag == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _drag = 0);
      return;
    }
    _settleFrom = _drag;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final Size screen = MediaQuery.sizeOf(context);
    final double maxHeight = screen.height * widget.maxHeightFactor;
    final Color surface = widget.backgroundColor ?? TavoColors.background;

    final Widget shell = Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TavoRadii.sheet),
        ),
        boxShadow: TavoShadows.xxl,
      ),
      child: Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TavoRadii.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.showHandle)
                SizedBox(
                  height: 24,
                  child: Center(
                    child: Container(
                      key: TavoSheet.handleKey,
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TavoColors.handle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              if (widget.title != null || widget.subtitle != null)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    TavoSpace.xl,
                    TavoSpace.sm,
                    TavoSpace.xl,
                    TavoSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (widget.title != null)
                        Text(
                          widget.title!,
                          style: TavoType.h3.copyWith(
                            color: TavoColors.foreground,
                          ),
                        ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: TavoSpace.xs),
                        Text(
                          widget.subtitle!,
                          style: TavoType.bodySmall.copyWith(
                            color: TavoColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (widget.showHandle)
                const SizedBox(height: TavoSpace.sm),
              Flexible(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    widget.title == null ? TavoSpace.lg : TavoSpace.xl,
                    0,
                    widget.title == null ? TavoSpace.lg : TavoSpace.xl,
                    TavoSpace.xl,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget constrained = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: widget.maxWidth,
      ),
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: SizedBox(width: double.infinity, child: shell),
      ),
    );

    final Widget centered = Align(
      alignment: Alignment.bottomCenter,
      child: constrained,
    );

    final Widget draggable = GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: centered,
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: keyboard),
      child: draggable,
    );
  }
}
