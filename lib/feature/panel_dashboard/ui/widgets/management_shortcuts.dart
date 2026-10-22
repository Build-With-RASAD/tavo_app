// lib/feature/panel_dashboard/ui/widgets/management_shortcuts.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';

/// The management shortcuts: the screens a manager opens every shift.
///
/// Each tile names a More-hub entry (`menu`, `staff`, `branches`, `reviews`,
/// `settings`, `invoices`) and hands that id to the shell, which owns the
/// navigation.
class ManagementShortcuts extends StatelessWidget {
  const ManagementShortcuts({super.key, this.onOpenHub});

  /// Opens the More-hub screen with this id.
  final void Function(String hubId)? onOpenHub;

  /// The tiles, in order.
  static const List<({String id, String labelKey, IconData icon})> _tiles = [
    (id: 'menu', labelKey: 'dash_shortcut_menu', icon: Icons.restaurant_menu_outlined),
    (id: 'staff', labelKey: 'dash_shortcut_staff', icon: Icons.badge_outlined),
    (id: 'branches', labelKey: 'dash_shortcut_branches', icon: Icons.storefront_outlined),
    (id: 'reviews', labelKey: 'dash_shortcut_reviews', icon: Icons.star_border),
    (id: 'settings', labelKey: 'dash_shortcut_settings', icon: Icons.settings_outlined),
    (id: 'invoices', labelKey: 'dash_shortcut_invoices', icon: Icons.receipt_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10.w,
      crossAxisSpacing: 10.w,
      childAspectRatio: 1.05,
      children: [
        for (final tile in _tiles)
          InkWell(
            key: ValueKey('dash_shortcut_${tile.id}'),
            onTap: onOpenHub == null ? null : () => onOpenHub!(tile.id),
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              decoration: BoxDecoration(
                color: ColorsManager.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: ColorsManager.grey100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tile.icon, size: 22.r, color: ColorsManager.primary500),
                  SizedBox(height: 6.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      tile.labelKey.tr(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.font10DarkGray400Weight(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
