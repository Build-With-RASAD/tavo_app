// lib/core/ui/tavo_web/tavo_surfaces.dart
//
// Content surfaces sampled from the marketing site:
//
//   restaurant/review card  → rounded-2xl (16), bg-card #FDFDFA, hairline border
//   feature/category card   → rounded-3xl (24), bg-muted #F4F4F4
//   tag badge               → glass pill, 24 high, 11/600, gold icon
//   eyebrow chip            → #F5C444 pill, dark ink, 14/600
//   stat block              → 48/48 tabular figures, uppercase 12/500 label
//
// None of these read copy from the kit. Every string (label, title, badge)
// is passed in already localised. Layout is logical-only, so Arabic mirrors
// without an `if (isRtl)` in the caller.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tavo_tokens.dart';

/// Semantic meaning, independent of colour. Used by pills, icon tiles and
/// anything that needs a status hue without hard-coding one.
enum TavoTone {
  /// Brand gold. On tinted surfaces the glyph uses brand-800 for contrast.
  brand,

  /// App-side success green (the site defines no success token).
  success,

  /// App-side informational blue.
  info,

  /// App-side warning amber.
  warning,

  /// App-side destructive red.
  danger,

  /// Neutral / no status.
  neutral,
}

Color _toneColor(TavoTone tone) {
  switch (tone) {
    case TavoTone.brand:
      return TavoColors.brand700;
    case TavoTone.success:
      return TavoColors.success;
    case TavoTone.info:
      return TavoColors.info;
    case TavoTone.warning:
      return TavoColors.warning;
    case TavoTone.danger:
      return TavoColors.danger;
    case TavoTone.neutral:
      return TavoColors.mutedForeground;
  }
}

/// A glyph colour that clears 3:1 on its own 10–12% tint.
Color _toneForeground(TavoTone tone) {
  switch (tone) {
    case TavoTone.brand:
      // #CC9416 on #FFF8E0 is ~2.6:1; one ramp step down clears 3:1.
      return TavoColors.brand800;
    case TavoTone.neutral:
      return TavoColors.foreground;
    case TavoTone.success:
    case TavoTone.info:
    case TavoTone.warning:
    case TavoTone.danger:
      return _toneColor(tone);
  }
}

/// `#FDFDFA` card on `#EFEFEF` hairline, or the site's `#FCF6E6` warm panel.
enum TavoCardVariant {
  /// Restaurant/review card: `bg-card`, `border`, `rounded-2xl`.
  plain,

  /// `#FCF6E6` — the gold-tinted panel (footer CTA, wordmark pill surfaces).
  warm,

  /// `#F4F4F4` — feature and category cards, `rounded-3xl`.
  muted,
}

/// The site's card shell.
///
/// ```dart
/// TavoCard(
///   onTap: () => openRestaurant(id),
///   child: Text(name, style: TavoType.title),
/// )
/// ```
class TavoCard extends StatefulWidget {
  /// Creates a card.
  const TavoCard({
    super.key,
    required this.child,
    this.variant = TavoCardVariant.plain,
    this.padding = const EdgeInsets.all(TavoSpace.cardTight),
    this.radius,
    this.shadow = TavoShadows.none,
    this.borderColor,
    this.onTap,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Card content.
  final Widget child;

  /// Which site surface to paint.
  final TavoCardVariant variant;

  /// Inner padding. Defaults to `p-4` — panel density rather than the
  /// site's roomier `p-6`.
  final EdgeInsetsGeometry padding;

  /// Overrides the variant radius. Plain is 16, warm/muted are 24.
  final double? radius;

  /// Resting shadow. A tappable card lifts to `TavoShadows.lg` on hover,
  /// matching `hover:shadow-lg duration-200`.
  final List<BoxShadow> shadow;

  /// Overrides the hairline border colour (e.g. brand-500 for selection).
  final Color? borderColor;

  /// Makes the card tappable. No ripple: the site has none.
  final VoidCallback? onTap;

  /// Clip behaviour for image cards.
  final Clip clipBehavior;

  @override
  State<TavoCard> createState() => _TavoCardState();
}

class _TavoCardState extends State<TavoCard> {
  bool _hovered = false;

  double get _radius {
    if (widget.radius != null) return widget.radius!;
    switch (widget.variant) {
      case TavoCardVariant.plain:
        return TavoRadii.card;
      case TavoCardVariant.warm:
      case TavoCardVariant.muted:
        return TavoRadii.xxl;
    }
  }

  Color get _background {
    switch (widget.variant) {
      case TavoCardVariant.plain:
        return TavoColors.card;
      case TavoCardVariant.warm:
        return TavoColors.goldTint;
      case TavoCardVariant.muted:
        return TavoColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null;
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final BorderRadius shape = BorderRadius.circular(_radius);

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: reducedMotion ? Duration.zero : TavoMotion.fast,
        curve: TavoMotion.out,
        clipBehavior: widget.clipBehavior,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: shape,
          border: Border.all(
            color:
                widget.borderColor ??
                (widget.variant == TavoCardVariant.plain
                    ? TavoColors.border
                    : Colors.transparent),
          ),
          boxShadow: (_hovered && interactive)
              ? TavoShadows.lg
              : widget.shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: shape,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            canRequestFocus: interactive,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// `text-xs font-semibold uppercase tracking-wide` label over a 48 px
/// tabular figure (`waitlist/page.tsx` ticket code).
class TavoStatTile extends StatelessWidget {
  /// Creates a stat tile.
  const TavoStatTile({
    super.key,
    required this.label,
    required this.value,
    this.prefix,
    this.suffix,
    this.decimals = 0,
    this.icon,
    this.badge,
    this.hero = false,
    this.tone = TavoTone.neutral,
    this.padding = const EdgeInsets.all(TavoSpace.cardTight),
    this.onTap,
  });

  /// Uppercase label, already localised.
  final String label;

  /// The figure. Grouped with `,` and rendered in tabular figures.
  final num value;

  /// Rendered before [value] (`SAR`, `#`), already localised.
  final String? prefix;

  /// Rendered after [value] (`%`, `orders`).
  final String? suffix;

  /// Decimal places to keep. `0` rounds to a whole number.
  final int decimals;

  /// Optional glyph shown at the top-end of the tile.
  final Widget? icon;

  /// Optional trailing widget under the figure — a [TavoStatusPill] with a
  /// delta, for example.
  final Widget? badge;

  /// Uses the site's 48 px figure instead of the panel's 28 px one.
  final bool hero;

  /// Only used to tint [icon] when no explicit colour is supplied.
  final TavoTone tone;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Makes the tile tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = hero
        ? TavoType.stat
        : TavoType.statCompact;

    final Widget figure = Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (prefix != null)
            TextSpan(
              text: '$prefix ',
              style: TavoType.bodySmall.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          TextSpan(
            text: TavoNumberFormat.grouped(value, decimals: decimals),
            style: valueStyle.copyWith(color: TavoColors.foreground),
          ),
          if (suffix != null)
            TextSpan(
              text: ' $suffix',
              style: TavoType.caption.copyWith(
                color: TavoColors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TavoType.overline.copyWith(
                  color: TavoColors.mutedForeground,
                ),
              ),
            ),
            if (icon != null) ...<Widget>[
              const SizedBox(width: TavoSpace.sm),
              IconTheme.merge(
                data: IconThemeData(color: _toneForeground(tone), size: 18),
                child: icon!,
              ),
            ],
          ],
        ),
        const SizedBox(height: TavoSpace.sm),
        figure,
        if (badge != null) ...<Widget>[
          const SizedBox(height: TavoSpace.xs),
          badge!,
        ],
      ],
    );

    return TavoCard(
      padding: padding,
      onTap: onTap,
      child: content,
    );
  }
}

/// Thousands grouping without `intl` (the app already depends on it, but the
/// kit must not add imports beyond Flutter).
abstract final class TavoNumberFormat {
  /// `1234567` → `1,234,567`; `1234.5` with `decimals: 1` → `1,234.5`.
  static String grouped(num value, {int decimals = 0}) {
    final String fixed = value.abs().toStringAsFixed(decimals);
    final List<String> parts = fixed.split('.');
    final String digits = parts.first;
    final StringBuffer grouped = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }

    final String body = parts.length == 2
        ? '$grouped.${parts[1]}'
        : grouped.toString();
    return value < 0 ? '-$body' : body;
  }
}

/// Section heading + optional subtitle and action, matching the site's
/// `flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between`.
class TavoSectionHeader extends StatelessWidget {
  /// Creates a section header.
  const TavoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.dense = false,
  });

  /// Section title, already localised.
  final String title;

  /// Optional supporting line.
  final String? subtitle;

  /// Optional trailing action — usually a [TavoButton] or a text link.
  final Widget? action;

  /// Uses the 20 px heading instead of the 30 px one; for panel sections
  /// that already sit under a screen title.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: (dense ? TavoType.h3 : TavoType.h2).copyWith(
            color: TavoColors.foreground,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: TavoSpace.xs),
          Text(
            subtitle!,
            style: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
        ],
      ],
    );

    if (action == null) return heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: heading),
        const SizedBox(width: TavoSpace.md),
        action!,
      ],
    );
  }
}

/// Pill height presets. `regular` is the panel default; `small` is for
/// dense table rows.
enum TavoPillSize {
  /// 22 px painted.
  small,

  /// 28 px painted.
  regular,
}

/// Status pill: tinted background, `#111111` label, coloured dot.
///
/// Coloured text on a 12% tint lands at ~2.7:1, so the hue lives in the dot
/// and the label stays ink.
class TavoStatusPill extends StatelessWidget {
  /// Creates a status pill.
  const TavoStatusPill({
    super.key,
    required this.label,
    this.tone = TavoTone.neutral,
    this.size = TavoPillSize.regular,
    this.leading,
  });

  /// Localised status text.
  final String label;

  /// Status hue.
  final TavoTone tone;

  /// Painted height preset.
  final TavoPillSize size;

  /// Replaces the coloured dot (an Iconsax glyph, for example).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final Color hue = _toneColor(tone);
    final bool small = size == TavoPillSize.small;
    final double dot = small ? 6 : 7;

    return Container(
      height: small ? 22 : 28,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: small ? TavoSpace.sm : TavoSpace.pillHorizontal,
      ),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(TavoRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null)
            IconTheme.merge(
              data: IconThemeData(color: hue, size: dot + 5),
              child: leading!,
            )
          else
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
            ),
          const SizedBox(width: TavoSpace.xs),
          // Flexible, not plain Text: a long status ("Read only — you cannot
          // edit the menu") otherwise overflows a pill that sits in a
          // constrained row instead of ellipsizing.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (small ? TavoType.micro : TavoType.caption).copyWith(
                color: TavoColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three pill idioms the site actually uses.
enum TavoChipVariant {
  /// Selectable filter chip: `#F4F4F4` at rest, ink when selected.
  filter,

  /// `#F5C444` eyebrow pill (`how-it-works-section.tsx`).
  gold,

  /// `#111111` 62% glass pill over photography (`.tavo-tag-badge`).
  glass,
}

/// A pill. Filter chips are tappable; gold and glass chips are labels.
class TavoChip extends StatelessWidget {
  /// Creates a chip.
  const TavoChip({
    super.key,
    required this.label,
    this.variant = TavoChipVariant.filter,
    this.selected = false,
    this.onTap,
    this.leading,
  });

  /// Localised label.
  final String label;

  /// Pill idiom.
  final TavoChipVariant variant;

  /// Selection state for [TavoChipVariant.filter].
  final bool selected;

  /// Tap handler. `null` renders a static label.
  final VoidCallback? onTap;

  /// Optional leading glyph. Recoloured to match the pill.
  final Widget? leading;

  bool get _isGlass => variant == TavoChipVariant.glass;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final double paintedHeight = _isGlass ? 24 : 32;
    final double outerHeight = enabled
        ? math.max(paintedHeight, TavoSpace.minTouchTarget)
        : paintedHeight;

    late final Color background;
    late final Color foreground;
    late final Color? border;
    late final TextStyle textStyle;

    switch (variant) {
      case TavoChipVariant.filter:
        background = selected ? TavoColors.foreground : TavoColors.muted;
        foreground = selected ? TavoColors.background : TavoColors.foreground;
        border = null;
        textStyle = TavoType.label;
      case TavoChipVariant.gold:
        background = TavoColors.goldEyebrow;
        foreground = TavoColors.foreground;
        border = null;
        textStyle = TavoType.label;
      case TavoChipVariant.glass:
        background = TavoColors.glass;
        foreground = TavoColors.background;
        border = TavoColors.glassBorder;
        textStyle = TavoType.micro;
    }

    final double radius = TavoRadii.pill;
    final double horizontalPadding = _isGlass
        ? TavoSpace.pillHorizontal
        : TavoSpace.md;
    final List<BoxShadow>? shadow = switch (variant) {
      TavoChipVariant.gold => TavoShadows.cta,
      TavoChipVariant.glass => TavoShadows.badge,
      TavoChipVariant.filter => null,
    };

    final Widget pill = AnimatedContainer(
      duration: TavoMotion.fast,
      curve: TavoMotion.out,
      height: paintedHeight,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            IconTheme.merge(
              data: IconThemeData(
                color: _isGlass ? TavoColors.brand300 : foreground,
                size: _isGlass ? 14 : 16,
              ),
              child: leading!,
            ),
            SizedBox(width: _isGlass ? TavoSpace.xs : TavoSpace.sm),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(color: foreground),
          ),
        ],
      ),
    );

    if (!enabled) return pill;

    return Semantics(
      button: true,
      selected: variant == TavoChipVariant.filter ? selected : null,
      child: SizedBox(
        height: outerHeight,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}

/// Square or circular icon plate — the site's 44 px feature badge and its
/// 64 px `rounded-2xl` category image slot.
class TavoIconTile extends StatelessWidget {
  /// Creates an icon tile.
  const TavoIconTile({
    super.key,
    required this.icon,
    this.tone = TavoTone.brand,
    this.size = 44,
    this.radius,
  });

  /// The glyph (usually Iconsax, 20–24 px).
  final Widget icon;

  /// Plate hue.
  final TavoTone tone;

  /// Outer square size.
  final double size;

  /// Overrides the plate radius. Pass [TavoRadii.pill] for a circle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final Color hue = _toneColor(tone);

    return Container(
      width: size,
      height: size,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: switch (tone) {
          TavoTone.neutral => TavoColors.muted,
          // The site's icon plates are brand-50 with a brand-800 glyph;
          // other tones use a 10% tint because the site has no such token.
          TavoTone.brand => TavoColors.brand50,
          _ => hue.withValues(alpha: 0.10),
        },
        borderRadius: BorderRadius.circular(radius ?? TavoRadii.xl),
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: _toneForeground(tone),
          size: size * 0.48,
        ),
        child: icon,
      ),
    );
  }
}
