// lib/feature/panel_dashboard/ui/widgets/comparison_row.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The period-over-period comparison: this window against the window right
/// before it.
///
/// A `null` delta (the previous period was zero) renders as an em dash —
/// never a fake 0% and never an invented 100%.
class ComparisonRow extends StatelessWidget {
  const ComparisonRow({super.key, required this.comparison});

  /// The comparison payload.
  final AnalyticsComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'dash_comparison_revenue'.tr(),
                value: formatMoney(comparison.revenue.current),
                deltaPct: comparison.revenue.deltaPct,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _MetricTile(
                label: 'dash_comparison_orders'.tr(),
                value: formatCount(comparison.orders.current),
                deltaPct: comparison.orders.deltaPct,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'dash_comparison_ticket'.tr(),
                value: formatMoney(comparison.avgOrderValue.current),
                deltaPct: comparison.avgOrderValue.deltaPct,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _MetricTile(
                label: 'dash_comparison_reservations'.tr(),
                value: formatCount(comparison.reservations.current),
                deltaPct: comparison.reservations.deltaPct,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.deltaPct,
  });

  final String label;
  final String value;
  final double? deltaPct;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPct;
    final color = delta == null
        ? ColorsManager.darkGray400
        : delta > 0
            ? ColorsManager.success500
            : delta < 0
                ? ColorsManager.errorColor
                : ColorsManager.darkGray400;

    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.font10DarkGray400Weight(context),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.font14Black500Weight(context),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              if (delta != null && delta != 0)
                Icon(
                  delta > 0
                      ? Iconsax.arrow_up_2
                      : Iconsax.arrow_down_2,
                  size: 12.r,
                  color: color,
                ),
              SizedBox(width: 2.w),
              Text(
                formatDelta(delta),
                style: TextStyles.font10DarkGray400Weight(context)
                    .copyWith(color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
