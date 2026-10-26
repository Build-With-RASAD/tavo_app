// lib/core/ui/tavo_web/tavo_tokens.dart
//
// Design tokens sampled from the Tavo marketing/guest website
// (`Tavo-Website/src/app/globals.css`, `tailwind.config.mjs`).
//
// Every value below exists on the website. Nothing here is an invented
// shade: where the site has no token (success/warning/info) the value is
// taken from the app's existing palette and marked "app-side" in the doc.
//
// Units are logical pixels (the site's CSS px). The kit deliberately does
// not scale through flutter_screenutil so a token means the same thing in
// the app, in a test, and in the design doc.

import 'package:flutter/material.dart';

import '../../theme/fonts.dart' show kArabicFontFamily;

/// Site colors — `globals.css` `:root` (lines 70–100).
///
/// The brand ramp is the site's full gold scale. `primary` is brand-500,
/// the exact fill of every gold CTA on the site; `onPrimary` is the site's
/// foreground ink, because every real CTA uses `text-[#111111]` on gold.
abstract final class TavoColors {
  // -- Brand ramp (`--color-brand-*`) -------------------------------------
  static const Color brand50 = Color(0xFFFFF8E0);
  static const Color brand100 = Color(0xFFFFEDB3);
  static const Color brand200 = Color(0xFFFFE080);
  static const Color brand300 = Color(0xFFFFD24D);
  static const Color brand400 = Color(0xFFFFC526);
  static const Color brand500 = Color(0xFFFFBF1E);
  static const Color brand600 = Color(0xFFE5A91A);
  static const Color brand700 = Color(0xFFCC9416);
  static const Color brand800 = Color(0xFFB37F12);
  static const Color brand900 = Color(0xFF996A0E);
  static const Color brand950 = Color(0xFF80550B);

  // -- Semantic surfaces ---------------------------------------------------
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF111111);
  static const Color muted = Color(0xFFF4F4F4);
  static const Color mutedForeground = Color(0xFF5F5F5F);
  static const Color border = Color(0xFFEFEFEF);
  static const Color input = Color(0xFFE9E9E9);
  static const Color ring = Color(0xFFFFBF1E);
  static const Color accent = Color(0xFFF4F4F4);
  static const Color accentForeground = Color(0xFF111111);
  static const Color card = Color(0xFFFDFDFA);
  static const Color cardForeground = Color(0xFF111111);
  static const Color popover = Color(0xFFFDFDFA);
  static const Color secondary = Color(0xFF3E416C);
  static const Color secondary600 = Color(0xFF343762);

  /// Site token (`--color-destructive`). Used for tints and badges.
  static const Color destructive = Color(0xFFEF4444);

  /// Solid destructive fill. The site's own pair (`#EF4444` + `#FAFAFA`)
  /// is 3.6:1, below AA for a 14 px label, and the site never renders a
  /// solid destructive button. The two solid stops below are Tailwind
  /// red-600/700/800 — the same palette the site's config extends — so the
  /// button stays in-language while clearing 4.5:1.
  static const Color destructiveSolid = Color(0xFFDC2626);
  static const Color destructiveSolidHover = Color(0xFFB91C1C);
  static const Color destructiveSolidPressed = Color(0xFF991B1B);
  static const Color onDestructive = Color(0xFFFAFAFA);
  static const Color grayBgLight = Color(0xFFEFEFEF);

  // -- Site literals used repeatedly in components -------------------------
  /// `#FDFDFA` — section canvas on the home page.
  static const Color canvas = Color(0xFFFDFDFA);

  /// `#FCF6E6` — the gold-tinted pill behind the "Tavo" wordmark.
  static const Color goldTint = Color(0xFFFCF6E6);

  /// `#666666` — secondary meta text inside review cards.
  static const Color inkSoft = Color(0xFF666666);

  /// `#D9D9D9` — the site's neutral for scrollbar thumbs; reused as the
  /// bottom-sheet drag handle because the site has no other neutral.
  static const Color handle = Color(0xFFD9D9D9);

  /// `#F5C444` — the how-it-works eyebrow pill
  /// (`how-it-works-section.tsx` line 120).
  static const Color goldEyebrow = Color(0xFFF5C444);

  /// `#F0BC2E` — the same pill's hover fill.
  static const Color goldEyebrowHover = Color(0xFFF0BC2E);

  /// `rgb(17 17 17 / 0.62)` — `.tavo-tag-badge` glass fill.
  static const Color glass = Color(0x9E111111);

  /// `rgb(255 255 255 / 0.16)` — `.tavo-tag-badge` hairline.
  static const Color glassBorder = Color(0x29FFFFFF);

  // -- Action aliases ------------------------------------------------------
  static const Color primary = brand500;
  static const Color primaryHover = brand600;
  static const Color primaryPressed = brand700;

  /// Dark ink sits on gold on the site (`text-[#111111]`). White on
  /// `#FFBF1E` is ~1.7:1 and was never used for a gold surface.
  static const Color onPrimary = foreground;

  /// The restaurant app's legacy brand gold (`ColorsManager.primaryColor`).
  /// Kept only so migrating screens can bridge; the kit does not use it.
  static const Color appGold = Color(0xFFFFA100);

  // -- Status (app-side: the site defines no success/warning/info) ---------
  /// `StatusBadge.colorFor` in `lib/core/widgets/status_badge.dart`.
  static const Color success = Color(0xFF22A83A);
  static const Color info = Color(0xFF1565C0);
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFFB26A00);

  /// `foreground/50` — the site's menu backdrop (`bg-foreground/50`).
  static const Color overlay = Color(0x80111111);
}

/// Site radii — `--radius-*` (globals.css 102–106) plus the utilities the
/// components actually use (`rounded-3xl`, `rounded-[32px]`, `rounded-full`).
abstract final class TavoRadii {
  /// `--radius-sm` 0.25rem.
  static const double xs = 4;

  /// `--radius-md` 0.375rem — the `Button` component's `rounded-md`.
  static const double sm = 6;

  /// `--radius-lg` 0.5rem.
  static const double md = 8;

  /// `--radius-xl` 0.75rem — testimonial and owner-response cards.
  static const double lg = 12;

  /// `--radius-2xl` 1rem — restaurant and review cards.
  static const double xl = 16;

  /// `rounded-3xl` 1.5rem — feature, category and waitlist-ticket cards.
  static const double xxl = 24;

  /// `rounded-[32px]` — footer cards, mobile menu, search bar.
  static const double xxxl = 32;

  /// `rounded-[40px]` — the hero frame and footer top.
  static const double hero = 40;

  /// `rounded-full`.
  static const double pill = 999;

  // Component aliases (single source of truth for the kit).
  static const double button = pill;
  static const double card = xl;
  static const double sheet = xxxl;
}

/// Spacing — Tailwind's 4 px rhythm as used on the site.
abstract final class TavoSpace {
  static const double none = 0;

  /// `gap-1` / `mt-1`.
  static const double xxs = 4;

  /// `gap-1.5`.
  static const double xs = 6;

  /// `gap-2` / `py-2`.
  static const double sm = 8;

  /// `gap-3` / `py-3`.
  static const double md = 12;

  /// `px-4` / `p-4` / `gap-4`.
  static const double lg = 16;

  /// `px-6` / `p-6` / `gap-6`.
  static const double xl = 24;

  /// `gap-8` / `p-8` / `py-20` half.
  static const double xxl = 32;

  /// `gap-10` — the gap inside feature cards.
  static const double xxxl = 40;

  /// `gap-12` — section header to content.
  static const double huge = 48;

  /// `py-20` — the vertical rhythm between home sections.
  static const double section = 80;

  /// `px-4` page gutter.
  static const double gutter = 16;

  /// `md:px-6` page gutter.
  static const double gutterWide = 24;

  /// `p-6` card padding.
  static const double card = 24;

  /// `p-4` tight card padding.
  static const double cardTight = 16;

  /// Pill horizontal padding (`px-2.5` / tag badge `0 10px`).
  static const double pillHorizontal = 10;

  /// Pill vertical padding (`py-1`).
  static const double pillVertical = 4;

  /// Minimum interactive target. The site's largest button is 44 px
  /// (`h-11` / `py-3`), so the kit paints at most 48 and always accepts
  /// taps across at least 48.
  static const double minTouchTarget = 48;
}

/// Type scale — Tailwind's `text-*` sizes as used by the site, rendered in
/// the app's existing family (`kArabicFontFamily` = `norsal`). No font is
/// added by this kit.
abstract final class TavoType {
  static const String family = kArabicFontFamily;

  /// `tabular-nums` — every figure that lines up in a column.
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// `text-4xl` 36/40, bold.
  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 40 / 36,
    fontWeight: FontWeight.w700,
  );

  /// `text-3xl` 30/36, bold.
  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 30,
    height: 36 / 30,
    fontWeight: FontWeight.w700,
  );

  /// `text-2xl` 24/32, bold.
  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );

  /// `text-xl` 20/28, bold.
  static const TextStyle h3 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );

  /// `text-lg font-semibold` 18/28 — feature and category card titles.
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
  );

  /// `text-base` 16/24.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// `text-sm` 14/20 — body copy and card descriptions.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// `text-sm font-semibold` 14/20 — every CTA label and section action.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  /// `text-xs` 12/16.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// `text-xs font-semibold uppercase tracking-wide` — stat labels,
  /// menu column headings. Callers pass an already-uppercased string;
  /// Flutter has no `text-transform`.
  static const TextStyle overline = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3, // tracking-wide = 0.025em of 12px
  );

  /// 11/11, semibold, `tracking-[0.01em]` — the glass tag pill on photo
  /// overlays (`globals.css` line 286).
  static const TextStyle micro = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.11,
  );

  /// `text-5xl font-bold tabular-nums` 48/48 — the site's hero stat
  /// (waitlist ticket code, line 161).
  static const TextStyle stat = TextStyle(
    fontFamily: family,
    fontSize: 48,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
  );

  /// 28/32, bold, tabular — the kit's dense panel tile. The site's 48 px
  /// stat does not fit a two-column phone grid; both tokens exist.
  static const TextStyle statCompact = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
  );

  /// `tracking-[0.3em]` — a code/ticket value. Pair with [stat].
  static const TextStyle statWide = TextStyle(
    fontFamily: family,
    fontSize: 48,
    height: 1,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
    letterSpacing: 14.4, // 0.3em of 48px
  );
}

/// Shadows — `--shadow-*` (globals.css 108–113) plus `shadow-2xl` and the
/// two bespoke shadows the site ships for badges and CTAs.
///
/// Flutter's `blurRadius` is used at the CSS value so the token stays
/// auditable against globals.css. Flutter's Skia blur is slightly softer
/// than Chrome's at the same number; if a surface reads too heavy, step
/// down one token instead of editing the value.
abstract final class TavoShadows {
  static const List<BoxShadow> none = <BoxShadow>[];

  /// `--shadow-sm` 0 1px 2px 0 rgb(0 0 0 / 0.05).
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// `--shadow-md` 0 4px 6px -1px + 0 2px 4px -2px, 10% black.
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// `--shadow-lg` 0 10px 15px -3px + 0 4px 6px -4px, 10% black.
  /// The site's card hover shadow (`hover:shadow-lg`).
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -4,
    ),
  ];

  /// `--shadow-xl` 0 20px 25px -5px + 0 8px 10px -6px, 10% black.
  static const List<BoxShadow> xl = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 8),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];

  /// `shadow-2xl` 0 25px 50px -12px rgb(0 0 0 / 0.25) — the nav menu panel
  /// and mobile menu.
  static const List<BoxShadow> xxl = <BoxShadow>[
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];

  /// `0 2px 8px -2px rgb(0 0 0 / 0.35)` — `.tavo-tag-badge`.
  static const List<BoxShadow> badge = <BoxShadow>[
    BoxShadow(
      color: Color(0x59000000),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];

  /// `0 8px 20px rgba(0,0,0,0.12)` — the how-it-works CTA.
  static const List<BoxShadow> cta = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 8), blurRadius: 20),
  ];
}

/// Motion tokens.
///
/// The site's GSAP tweens and CSS transitions collapse onto three durations
/// plus two heavier ones. Eases are GSAP power curves mapped to Flutter:
/// `power1`=quad, `power2`=cubic, `power3`=quart.
abstract final class TavoMotion {
  /// `duration-150` — colour/opacity state changes, focus rings.
  static const Duration fast = Duration(milliseconds: 150);

  /// The kit's default interaction beat (site CTA: `duration-200`).
  static const Duration base = Duration(milliseconds: 220);

  /// `duration-300` — nav bar condense, sheet and menu close.
  static const Duration slow = Duration(milliseconds: 300);

  /// GSAP `duration: 0.4` — feature-card tints, nav show/hide.
  static const Duration reveal = Duration(milliseconds: 400);

  /// GSAP `duration: 0.5` — menu panel open.
  static const Duration panel = Duration(milliseconds: 500);

  /// Stagger between revealed items. The site uses 50–100 ms for cards;
  /// the panel is denser, so 30 ms per item, capped at [maxStaggerItems].
  static const Duration stagger = Duration(milliseconds: 30);

  /// Index cap for the stagger — beyond this every item starts together.
  static const int maxStaggerItems = 8;

  /// GSAP `power2.out` / CSS `ease-out`.
  static const Cubic out = Curves.easeOutCubic;

  /// GSAP `power3.out` — cards, reveals, nav.
  static const Cubic outStrong = Curves.easeOutQuart;

  /// GSAP `power2.in` — exits and hover-leave.
  static const Cubic inCubic = Curves.easeInCubic;

  /// GSAP `power2.inOut`.
  static const Cubic inOut = Curves.easeInOutCubic;

  /// GSAP `power3.inOut` — the nav bar morph.
  static const Cubic inOutStrong = Curves.easeInOutQuart;

  /// GSAP `expo.out` — menu panel and mobile-menu entrance.
  static const Cubic expoOut = Curves.easeOutExpo;

  /// GSAP `back.out(~1.7)` — the chat widget's pop.
  static const Cubic overshoot = Curves.easeOutBack;

  /// `active:scale-[0.98]` on every site CTA.
  static const double pressScale = 0.98;

  /// `hover:scale-[1.03]` on every site CTA (desktop / pointer devices).
  static const double hoverScale = 1.03;
}
