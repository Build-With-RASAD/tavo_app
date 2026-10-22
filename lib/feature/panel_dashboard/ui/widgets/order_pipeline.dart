// lib/feature/panel_dashboard/ui/widgets/order_pipeline.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The order funnel: how many orders sit in each status right now.
///
/// Tapping a column opens the orders tab filtered by that status — the
/// status labels reuse the shared status keys (`pending`, `preparing`, …)
/// because they name exactly the same thing as everywhere else in the app.
class OrderPipeline extends StatelessWidget {
  const OrderPipeline({
    super.key,
    required this.ordersByStatus,
    this.onOpenOrders,
  });

  /// Counts by order status.
  final Map<String, int> ordersByStatus;

  /// Opens the orders tab for the tapped status.
  final void Function(String status)? onOpenOrders;

  /// The canonical funnel order, then any unknown status alphabetically.
  static List<String> orderedStatuses(Map<String, int> counts) {
    const order = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'served',
      'cancelled',
    ];
    final known = order.where(counts.containsKey).toList();
    final rest = counts.keys.where((s) => !order.contains(s)).toList()..sort();
    return [...known, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final statuses = orderedStatuses(ordersByStatus);
    if (statuses.isEmpty) {
      return const _EmptyPipeline();
    }
    final peak = statuses
        .map((status) => ordersByStatus[status] ?? 0)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final status in statuses)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: InkWell(
              key: ValueKey('dash_pipeline_$status'),
              onTap: onOpenOrders == null ? null : () => onOpenOrders!(status),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78.w,
                      child: Text(
                        status.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.font12DarkGray400Weight(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.r),
                        child: Stack(
                          children: [
                            Container(
                              height: 10.h,
                              color: ColorsManager.grey100,
                            ),
                            FractionallySizedBox(
                              widthFactor: _share(ordersByStatus[status] ?? 0, peak),
                              child: Container(
                                height: 10.h,
                                decoration: BoxDecoration(
                                  color: _colorFor(status),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    SizedBox(
                      width: 34.w,
                      child: Text(
                        formatCount(ordersByStatus[status] ?? 0),
                        textAlign: TextAlign.end,
                        style: TextStyles.font12Black500Weight(context),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16.r,
                      color: ColorsManager.darkGray300,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static double _share(int value, int peak) {
    if (peak <= 0) return 0;
    final share = value / peak;
    // A non-zero bar stays visible even for a tiny count.
    if (share <= 0) return 0;
    return (share < 0.06 ? 0.06 : share).clamp(0.0, 1.0).toDouble();
  }

  static Color _colorFor(String status) => switch (status) {
        'pending' => ColorsManager.secondary500,
        'confirmed' => ColorsManager.primary300,
        'preparing' => ColorsManager.primary500,
        'ready' => ColorsManager.teal,
        'cancelled' => ColorsManager.errorColor,
        _ => ColorsManager.success500,
      };
}

class _EmptyPipeline extends StatelessWidget {
  const _EmptyPipeline();

  @override
  Widget build(BuildContext context) {
    return Text(
      'dash_no_data_section'.tr(),
      style: TextStyles.font12DarkGray400Weight(context),
    );
  }
}
