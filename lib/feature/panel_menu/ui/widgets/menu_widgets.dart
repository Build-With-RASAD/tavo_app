// lib/feature/panel_menu/ui/widgets/menu_widgets.dart
//
// The menu module's visual vocabulary, built on the `tavo_web` kit so the
// panel reads like the marketing site rather than a stack of Material cards.
//
//   • MenuThumb        photo-led row/grid artwork with a branded fallback
//   • MenuFilterChip   pill with a real numeric count badge
//   • MenuItemRow      dense list row (default view)
//   • MenuItemTile     2-up grid tile (alternate view)
//   • MenuSearchField  debounced search input
//   • MenuEmpty/Error  honest states with the next useful action
//
// Everything is logical-only (`EdgeInsetsDirectional`, `start/end`), so the
// Arabic RTL build mirrors without a single `if (isRtl)`.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';

/// `32.0` → `32`, `32.5` → `32.5` — whole prices read without the `.0`.
String formatMenuPrice(double price) =>
    price == price.roundToDouble() ? '${price.round()}' : '$price';

/// `32 SAR`, already localised.
String menuPriceLabel(double price) =>
    '${formatMenuPrice(price)} ${'currency'.tr()}';

/// One localised name with a stable fallback to the other language.
String menuName(PanelMenuItem item, String locale) => item.name(locale);
String menuCategoryName(PanelMenuCategory category, String locale) =>
    category.name(locale);

/// Square artwork with a branded fallback. The fallback is a warm gradient
/// plate, not a grey box: a menu without photos is the normal state for a
/// venue that just onboarded.
class MenuThumb extends StatelessWidget {
  /// Creates a thumbnail.
  const MenuThumb({
    super.key,
    this.imageUrl,
    this.size = 64,
    this.radius = TavoRadii.lg,
  });

  /// Absolute image URL, or `null`/empty for the placeholder.
  final String? imageUrl;

  /// Painted square size. `null` fills the parent (grid artwork).
  final double? size;

  /// Corner radius. The grid passes a larger radius because it is clipped by
  /// the card itself.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    final bool hasImage = url != null && url.trim().isNotEmpty;

    final double? square = size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: square == null
          ? SizedBox.expand(child: _artwork(hasImage, url))
          : SizedBox(
              width: square,
              height: square,
              child: _artwork(hasImage, url),
            ),
    );
  }

  Widget _artwork(bool hasImage, String? url) {
    if (!hasImage) return _placeholder();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
    );
  }

  Widget _placeholder() {
    final double plate = size ?? 96;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[TavoColors.brand50, TavoColors.goldTint],
        ),
      ),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            end: -plate * 0.18,
            bottom: -plate * 0.18,
            child: Container(
              width: plate * 0.62,
              height: plate * 0.62,
              decoration: BoxDecoration(
                color: TavoColors.brand200.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(
              Iconsax.cup,
              size: plate * 0.38,
              color: TavoColors.brand800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill with a numeric count. The number is a **server** count
/// (see the cubit), never arithmetic over the rows currently on screen.
class MenuFilterChip extends StatelessWidget {
  /// Creates a filter chip.
  const MenuFilterChip({
    super.key,
    required this.label,
    this.count,
    this.selected = false,
    this.onTap,
    this.dotColor,
    this.leading,
  });

  /// Localised label.
  final String label;

  /// Server count rendered in the trailing badge. `null` hides the badge.
  final int? count;

  /// Selected chips paint ink with a light label.
  final bool selected;

  /// Tap handler; `null` renders a static chip.
  final VoidCallback? onTap;

  /// Optional status dot before the label.
  final Color? dotColor;

  /// Optional glyph before the label (replaces [dotColor]).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        selected ? TavoColors.background : TavoColors.foreground;
    final Color badgeBackground = selected
        ? Colors.white.withValues(alpha: 0.14)
        : TavoColors.foreground.withValues(alpha: 0.06);
    final Color badgeForeground =
        selected ? TavoColors.background : TavoColors.mutedForeground;

    final Widget pill = AnimatedContainer(
      duration: TavoMotion.fast,
      curve: TavoMotion.outStrong,
      height: 38,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavoSpace.md,
      ),
      decoration: BoxDecoration(
        color: selected ? TavoColors.foreground : TavoColors.muted,
        borderRadius: BorderRadius.circular(TavoRadii.pill),
        border: Border.all(
          color: selected ? TavoColors.foreground : TavoColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null)
            IconTheme.merge(
              data: IconThemeData(
                size: 14,
                color: selected ? TavoColors.background : TavoColors.brand800,
              ),
              child: leading!,
            )
          else if (dotColor != null)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          if (leading != null || dotColor != null)
            const SizedBox(width: TavoSpace.xs),
          Text(
            label,
            style: TavoType.label.copyWith(
              color: foreground,
              fontSize: 13,
            ),
          ),
          if (count != null) ...<Widget>[
            const SizedBox(width: TavoSpace.sm),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(TavoRadii.pill),
              ),
              child: Text(
                '$count',
                style: TavoType.caption.copyWith(
                  color: badgeForeground,
                  fontWeight: FontWeight.w700,
                  fontFeatures: TavoType.tabular,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: TavoPressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: pill,
        ),
      ),
    );
  }
}

/// Actions offered by a row's overflow menu.
enum MenuRowAction {
  /// Open the editor.
  edit,

  /// Flip availability.
  toggle,

  /// Pick and upload a photo.
  addPhoto,

  /// Clear the photo.
  removePhoto,

  /// Confirm and delete.
  delete,
}

/// Dense, photo-led list row — the menu's default view.
class MenuItemRow extends StatelessWidget {
  /// Creates a row.
  const MenuItemRow({
    super.key,
    required this.item,
    required this.categoryName,
    required this.locale,
    required this.acting,
    required this.manageable,
    required this.onOpen,
    required this.onAction,
  });

  final PanelMenuItem item;
  final String categoryName;
  final String locale;

  /// A mutation on this row is in flight.
  final bool acting;

  /// The role may mutate.
  final bool manageable;

  final VoidCallback onOpen;
  final ValueChanged<MenuRowAction> onAction;

  @override
  Widget build(BuildContext context) {
    final String description = item.description(locale);
    final int specCount = item.specifications.length;

    return TavoCard(
      padding: const EdgeInsets.all(10),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          MenuThumb(imageUrl: item.imageUrl, size: 68),
          const SizedBox(width: TavoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        menuName(item, locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavoType.label.copyWith(
                          color: TavoColors.foreground,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: TavoSpace.sm),
                    Text(
                      menuPriceLabel(item.price),
                      style: TavoType.label.copyWith(
                        color: TavoColors.foreground,
                        fontFeatures: TavoType.tabular,
                      ),
                    ),
                  ],
                ),
                if (description.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TavoType.caption.copyWith(
                      color: TavoColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: TavoSpace.xs),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: TavoSpace.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: TavoColors.muted,
                          borderRadius:
                              BorderRadius.circular(TavoRadii.xs),
                        ),
                        child: Text(
                          categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TavoType.micro.copyWith(
                            color: TavoColors.mutedForeground,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    if (specCount > 0) ...<Widget>[
                      const SizedBox(width: TavoSpace.xs),
                      Icon(
                        Iconsax.setting_2,
                        size: 12,
                        color: TavoColors.mutedForeground,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$specCount',
                        style: TavoType.micro.copyWith(
                          color: TavoColors.mutedForeground,
                          fontSize: 10,
                          fontFeatures: TavoType.tabular,
                        ),
                      ),
                    ],
                    const SizedBox(width: TavoSpace.sm),
                    TavoStatusPill(
                      key: ValueKey<String>('menu_status_${item.id}'),
                      label: item.active
                          ? 'menu_filter_active'.tr()
                          : 'menu_filter_inactive'.tr(),
                      tone: item.active ? TavoTone.success : TavoTone.neutral,
                      size: TavoPillSize.small,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: TavoSpace.xxs),
          if (acting)
            const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (manageable)
            _RowMenu(item: item, onAction: onAction),
        ],
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.item, required this.onAction});

  final PanelMenuItem item;
  final ValueChanged<MenuRowAction> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MenuRowAction>(
      key: ValueKey<String>('menu_actions_${item.id}'),
      tooltip: 'menu_actions'.tr(),
      color: TavoColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TavoRadii.lg),
        side: const BorderSide(color: TavoColors.border),
      ),
      offset: const Offset(0, 40),
      icon: const Icon(
        Iconsax.more,
        size: 20,
        color: TavoColors.mutedForeground,
      ),
      onSelected: onAction,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<MenuRowAction>>[
        _entry(MenuRowAction.edit, Iconsax.edit_2, 'edit_item'.tr()),
        _entry(
          MenuRowAction.toggle,
          item.active ? Iconsax.close_circle : Iconsax.tick_circle,
          item.active ? 'menu_hide_item'.tr() : 'menu_show_item'.tr(),
        ),
        _entry(
          MenuRowAction.addPhoto,
          Iconsax.gallery_add,
          item.hasImage ? 'change_photo'.tr() : 'add_photo'.tr(),
        ),
        if (item.hasImage)
          _entry(
            MenuRowAction.removePhoto,
            Iconsax.gallery_slash,
            'remove_photo'.tr(),
          ),
        const PopupMenuDivider(),
        _entry(
          MenuRowAction.delete,
          Iconsax.trash,
          'delete_item'.tr(),
          destructive: true,
        ),
      ],
    );
  }

  PopupMenuItem<MenuRowAction> _entry(
    MenuRowAction value,
    IconData icon,
    String label, {
    bool destructive = false,
  }) {
    final Color color =
        destructive ? TavoColors.destructiveSolid : TavoColors.foreground;
    return PopupMenuItem<MenuRowAction>(
      value: value,
      height: 44,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: TavoSpace.md),
          Text(
            label,
            style: TavoType.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo-led grid tile — the alternate view.
class MenuItemTile extends StatelessWidget {
  /// Creates a tile.
  const MenuItemTile({
    super.key,
    required this.item,
    required this.categoryName,
    required this.locale,
    required this.acting,
    required this.manageable,
    required this.onOpen,
    required this.onAction,
  });

  final PanelMenuItem item;
  final String categoryName;
  final String locale;
  final bool acting;
  final bool manageable;
  final VoidCallback onOpen;
  final ValueChanged<MenuRowAction> onAction;

  @override
  Widget build(BuildContext context) {
    return TavoCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MenuThumb(
                  imageUrl: item.imageUrl,
                  size: null,
                  radius: 0,
                ),
                PositionedDirectional(
                  top: TavoSpace.sm,
                  start: TavoSpace.sm,
                  child: TavoStatusPill(
                    label: item.active
                        ? 'menu_filter_active'.tr()
                        : 'menu_filter_inactive'.tr(),
                    tone: item.active ? TavoTone.success : TavoTone.neutral,
                    size: TavoPillSize.small,
                  ),
                ),
                if (manageable && !acting)
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: _RowMenu(item: item, onAction: onAction),
                  ),
                if (acting)
                  const ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TavoSpace.md,
              TavoSpace.sm,
              TavoSpace.md,
              TavoSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  menuName(item, locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TavoType.label.copyWith(
                    color: TavoColors.foreground,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavoType.micro.copyWith(
                          color: TavoColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      menuPriceLabel(item.price),
                      style: TavoType.label.copyWith(
                        color: TavoColors.foreground,
                        fontSize: 13,
                        fontFeatures: TavoType.tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled search input. The controller lives in the screen so clearing a
/// filter from outside can reset the text too.
class MenuSearchField extends StatelessWidget {
  /// Creates a search field.
  const MenuSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        return TextField(
          key: const ValueKey<String>('menu_search'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          style: TavoType.bodySmall.copyWith(color: TavoColors.foreground),
          cursorColor: TavoColors.foreground,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground,
            ),
            filled: true,
            fillColor: TavoColors.muted,
            prefixIcon: const Icon(
              Iconsax.search_normal_1,
              size: 18,
              color: TavoColors.mutedForeground,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 42,
              minHeight: 44,
            ),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey<String>('menu_search_clear'),
                    tooltip: 'clear'.tr(),
                    icon: const Icon(
                      Iconsax.close_circle,
                      size: 18,
                      color: TavoColors.mutedForeground,
                    ),
                    onPressed: onClear,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 44,
            ),
            contentPadding: const EdgeInsetsDirectional.symmetric(
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TavoRadii.pill),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TavoRadii.pill),
              borderSide: const BorderSide(color: TavoColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TavoRadii.pill),
              borderSide: const BorderSide(
                color: TavoColors.brand500,
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Square icon-only pager button with a logical chevron.
class MenuPageButton extends StatelessWidget {
  /// Creates a pager button.
  const MenuPageButton({
    super.key,
    required this.back,
    required this.onPressed,
    required this.tooltip,
  });

  /// `true` renders the direction-aware "previous" chevron.
  final bool back;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final IconData icon = back
        ? (rtl ? Iconsax.arrow_right_2 : Iconsax.arrow_left_2)
        : (rtl ? Iconsax.arrow_left_2 : Iconsax.arrow_right_2);
    final bool enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: TavoPressScale(
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TavoColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: TavoColors.border),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? TavoColors.foreground
                    : TavoColors.mutedForeground.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static skeleton (no shimmer): an endless animation would keep
/// `pumpAndSettle` spinning in tests and buys nothing on a fast panel.
class MenuSkeletonList extends StatelessWidget {
  /// Creates a skeleton list.
  const MenuSkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.gutter,
        TavoSpace.sm,
        TavoSpace.gutter,
        TavoSpace.xl,
      ),
      itemCount: rows,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: TavoSpace.md),
      itemBuilder: (BuildContext context, int index) => TavoCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: TavoColors.muted,
                borderRadius: BorderRadius.circular(TavoRadii.lg),
              ),
            ),
            const SizedBox(width: TavoSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _bar(width: 150, height: 12),
                  const SizedBox(height: TavoSpace.sm),
                  _bar(width: 220, height: 9),
                  const SizedBox(height: TavoSpace.sm),
                  _bar(width: 80, height: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: TavoColors.muted,
          borderRadius: BorderRadius.circular(TavoRadii.xs),
        ),
      );
}

/// Empty menu / empty filter result, with the next useful action.
class MenuEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const MenuEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TavoSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TavoIconTile(
              icon: Icon(icon, size: 30),
              size: 72,
              radius: TavoRadii.pill,
            ),
            const SizedBox(height: TavoSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TavoType.title.copyWith(color: TavoColors.foreground),
            ),
            const SizedBox(height: TavoSpace.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TavoType.bodySmall.copyWith(
                  color: TavoColors.mutedForeground,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: TavoSpace.xl),
              TavoButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                leading: const Icon(Iconsax.add, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Load failure with a retry, without wiping the rest of the screen.
class MenuErrorState extends StatelessWidget {
  /// Creates an error state.
  const MenuErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TavoSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const TavoIconTile(
              icon: Icon(Iconsax.warning_2, size: 28),
              tone: TavoTone.warning,
              size: 64,
              radius: TavoRadii.pill,
            ),
            const SizedBox(height: TavoSpace.lg),
            Text(
              'menu_load_failed'.tr(),
              textAlign: TextAlign.center,
              style: TavoType.title.copyWith(color: TavoColors.foreground),
            ),
            const SizedBox(height: TavoSpace.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TavoType.bodySmall.copyWith(
                  color: TavoColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: TavoSpace.xl),
            TavoButton.secondary(
              label: 'retry'.tr(),
              onPressed: () => onRetry(),
              leading: const Icon(Iconsax.refresh, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
