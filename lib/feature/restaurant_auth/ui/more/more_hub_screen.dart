// lib/feature/restaurant_auth/ui/more/more_hub_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';

/// "More" tab: the management hub grid (Menu, Tables, Customers, Staff,
/// Branches, Reviews, Settings, Contact & QR) assembled from
/// [MoreHubRegistry] so modules register themselves at DI time.
class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    final entries = MoreHubRegistry.entries;
    if (entries.isEmpty) {
      return Scaffold(
        body: EmptyStateView(
          icon: Icons.grid_view_outlined,
          title: 'hub_empty'.tr(),
        ),
      );
    }
    return Scaffold(
      body: GridView.builder(
        padding: EdgeInsets.all(16.w),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160.w,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 1.15,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          return InkWell(
            key: ValueKey('hub_${entry.id}'),
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => entry.builder(restaurantId, venue),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: ColorsManager.grey100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(entry.icon, size: 32.sp, color: ColorsManager.primaryColor),
                  SizedBox(height: 8.h),
                  Text(
                    entry.labelKey.tr(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.font14DarkGray400Weight(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
