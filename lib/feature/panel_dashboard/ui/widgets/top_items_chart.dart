// lib/feature/panel_dashboard/ui/widgets/top_items_chart.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The best sellers of the window: horizontal bars plus each item's share.
///
/// The bars grow from the START side, so they grow from the right in
/// Arabic — the RTL reading order is preserved.
class TopItemsChart extends StatelessWidget {
  const TopItemsChart({super.key, required this.items});

  /// The rows, already sorted by revenue (descending) by the backend.
  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'dash_no_data_section'.tr(),
        style: TextStyles.font12DarkGray400Weight(context),
      );
    }
    final peakShare = items.fold<double>(
      0,
      (max, item) => item.sharePct > max ? item.sharePct : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            key: ValueKey('dash_top_row_$i'),
            padding: EdgeInsets.only(bottom: 10.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.font12Black400Weight(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      formatPercent(items[i].sharePct, fractionDigits: 1),
                      style: TextStyles.font12Black500Weight(context),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: ColorsManager.grey100,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      key: ValueKey('dash_top_bar_$i'),
                      widthFactor: _share(items[i].sharePct, peakShare),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ColorsManager.primary500,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${formatCount(items[i].quantity)} · '
                  '${formatMoney(items[i].revenue)}',
                  style: TextStyles.font10DarkGray400Weight(context),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The bar width, relative to the biggest share.
  static double _share(double sharePct, double peakShare) {
    if (peakShare <= 0) return 0;
    final share = sharePct / peakShare;
    if (share <= 0) return 0;
    return (share < 0.04 ? 0.04 : share).clamp(0.0, 1.0).toDouble();
  }
}
