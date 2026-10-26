// lib/core/ui/tavo_web/tavo_buttons.dart
//
// Buttons that reproduce the website's CTA anatomy:
//
//   globals/hero CTA  → pill, gold #FFBF1E fill, #111111 label, 14/600
//   Button component  → h-9/10/11, rounded-md, sm/md/lg sizes
//   state             → hover +6% gold, press -6% gold, disabled 50%
//
// The painted pill is 40–48 px tall (the site's tallest is 44 px / h-11),
// and the tap target is always at least 48 px so the panel is usable one
// handed. No ripple: the site has none, so presses are expressed as the
// site's `active:scale-[0.98]` plus a colour step.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tavo_tokens.dart';

/// The four button roles the kit supports.
enum TavoButtonVariant {
  /// Gold fill, dark ink label — the site's primary CTA.
  primary,

  /// `bg-accent` fill, dark ink label — the site's secondary button.
  secondary,

  /// No fill at rest; accent fill on hover/press.
  ghost,

  /// `--color-destructive` fill with `--color-destructive-foreground`.
  destructive,
}

/// Painted height presets. Every preset keeps a ≥48 px tap target.
enum TavoButtonSize {
  /// 40 px painted — the site's `px-6 py-2.5` CTA height.
  compact,

  /// 44 px painted — the site's `py-3` form CTA (`h-11`).
  regular,

  /// 48 px painted — the site's `size="lg"` (`h-11` + `text-base`).
  large,
}

/// A Tavo button.
///
/// ```dart
/// TavoButton.primary(
///   label: t('save'),
///   leading: const Icon(Iconsax.tick_circle, size: 18),
///   onPressed: _save,
/// )
/// ```
class TavoButton extends StatefulWidget {
  /// Creates a button with an explicit [variant].
  const TavoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.variant = TavoButtonVariant.primary,
    this.size = TavoButtonSize.regular,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.loadingSemanticsLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Gold CTA.
  const TavoButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.size = TavoButtonSize.regular,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.loadingSemanticsLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = TavoButtonVariant.primary;

  /// Accent-filled secondary action.
  const TavoButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.size = TavoButtonSize.regular,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.loadingSemanticsLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = TavoButtonVariant.secondary;

  /// Borderless, fills with the accent colour on hover/press.
  const TavoButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.size = TavoButtonSize.regular,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.loadingSemanticsLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = TavoButtonVariant.ghost;

  /// Destructive action.
  const TavoButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.size = TavoButtonSize.regular,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expand = false,
    this.radius,
    this.loadingSemanticsLabel,
    this.focusNode,
    this.autofocus = false,
  }) : variant = TavoButtonVariant.destructive;

  /// Visible label. Never hard-coded by the kit — the caller passes the
  /// localised string.
  final String label;

  /// Tap handler. `null` renders the disabled state.
  final VoidCallback? onPressed;

  /// Long-press handler (optional).
  final VoidCallback? onLongPress;

  /// Which role the button plays.
  final TavoButtonVariant variant;

  /// Painted height preset.
  final TavoButtonSize size;

  /// Slot before the label (an Iconsax icon, an avatar, …).
  final Widget? leading;

  /// Slot after the label.
  final Widget? trailing;

  /// Swaps the label for a spinner and blocks taps.
  final bool isLoading;

  /// Whether the button fills its parent's width.
  final bool expand;

  /// Overrides [TavoRadii.button] (pill). Use [TavoRadii.sm] for dense
  /// toolbar buttons, matching the site's `rounded-md` Button.
  final double? radius;

  /// Semantics label announced while [isLoading] is true. Pass a localised
  /// string from the caller; the kit has no copy of its own.
  final String? loadingSemanticsLabel;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus on the first frame.
  final bool autofocus;

  @override
  State<TavoButton> createState() => _TavoButtonState();
}

class _TavoButtonState extends State<TavoButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _paintedHeight {
    switch (widget.size) {
      case TavoButtonSize.compact:
        return 40;
      case TavoButtonSize.regular:
        return 44;
      case TavoButtonSize.large:
        return 48;
    }
  }

  double get _horizontalPadding {
    switch (widget.size) {
      case TavoButtonSize.compact:
        return TavoSpace.lg; // px-4
      case TavoButtonSize.regular:
        return TavoSpace.xl; // px-6
      case TavoButtonSize.large:
        return TavoSpace.xxl; // px-8
    }
  }

  TextStyle get _labelStyle {
    switch (widget.size) {
      case TavoButtonSize.compact:
      case TavoButtonSize.regular:
        return TavoType.label;
      case TavoButtonSize.large:
        return TavoType.body.copyWith(fontWeight: FontWeight.w600);
    }
  }

  double get _iconSize => widget.size == TavoButtonSize.compact ? 16 : 18;

  _TavoButtonColors get _colors {
    switch (widget.variant) {
      case TavoButtonVariant.primary:
        final Color background = _pressed
            ? TavoColors.primaryPressed
            : (_hovered ? TavoColors.primaryHover : TavoColors.primary);
        return _TavoButtonColors(background, TavoColors.onPrimary);
      case TavoButtonVariant.secondary:
        // Site: bg-accent → hover:bg-accent/80 → active:bg-accent/90.
        final Color background = _pressed
            ? TavoColors.accent.withValues(alpha: 0.9)
            : (_hovered
                  ? TavoColors.accent.withValues(alpha: 0.8)
                  : TavoColors.accent);
        return _TavoButtonColors(background, TavoColors.accentForeground);
      case TavoButtonVariant.ghost:
        // Site: hover:bg-accent → active:bg-accent/80.
        final Color background = _pressed
            ? TavoColors.accent.withValues(alpha: 0.8)
            : (_hovered ? TavoColors.accent : Colors.transparent);
        return _TavoButtonColors(background, TavoColors.accentForeground);
      case TavoButtonVariant.destructive:
        // Site token #EF4444 fails AA with #FAFAFA (3.6:1), so the solid
        // fill uses the Tailwind red stops the site's palette extends.
        final Color background = _pressed
            ? TavoColors.destructiveSolidPressed
            : (_hovered
                  ? TavoColors.destructiveSolidHover
                  : TavoColors.destructiveSolid);
        return _TavoButtonColors(background, TavoColors.onDestructive);
    }
  }

  void _setHover(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final _TavoButtonColors colors = _colors;
    final double radius = widget.radius ?? TavoRadii.button;
    final BorderRadius shape = BorderRadius.circular(radius);
    final double outerHeight = math.max(_paintedHeight, TavoSpace.minTouchTarget);

    final Widget indicator = SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
      ),
    );

    final Widget body = widget.isLoading
        ? ExcludeSemantics(child: indicator)
        : Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.leading != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(color: colors.foreground, size: _iconSize),
                  child: widget.leading!,
                ),
                const SizedBox(width: TavoSpace.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _labelStyle.copyWith(color: colors.foreground),
                ),
              ),
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: TavoSpace.sm),
                IconTheme.merge(
                  data: IconThemeData(color: colors.foreground, size: _iconSize),
                  child: widget.trailing!,
                ),
              ],
            ],
          );

    final Widget surface = AnimatedContainer(
      duration: TavoMotion.fast,
      curve: TavoMotion.out,
      height: _paintedHeight,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: shape,
        border: Border.all(
          color: _focused ? TavoColors.ring : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _enabled ? widget.onPressed : null,
          onLongPress: _enabled ? widget.onLongPress : null,
          onHover: _setHover,
          onHighlightChanged: _setPressed,
          onFocusChange: _setFocused,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          canRequestFocus: _enabled,
          mouseCursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          borderRadius: shape,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: Center(widthFactor: 1, heightFactor: 1, child: body),
          ),
        ),
      ),
    );

    Widget result = SizedBox(
      height: outerHeight,
      child: Center(
        child: AnimatedScale(
          scale: (!reducedMotion && _pressed) ? TavoMotion.pressScale : 1,
          duration: TavoMotion.fast,
          curve: TavoMotion.out,
          child: widget.expand
              ? SizedBox(width: double.infinity, child: surface)
              : surface,
        ),
      ),
    );

    if (widget.isLoading && widget.loadingSemanticsLabel != null) {
      result = Semantics(label: widget.loadingSemanticsLabel, child: result);
    }

    if (widget.onPressed == null && !widget.isLoading) {
      // Site: `disabled:opacity-50`.
      result = Opacity(opacity: 0.5, child: result);
    }

    return result;
  }
}

class _TavoButtonColors {
  const _TavoButtonColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
