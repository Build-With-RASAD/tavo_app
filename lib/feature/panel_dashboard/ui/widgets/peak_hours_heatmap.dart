// lib/feature/panel_dashboard/ui/widgets/peak_hours_heatmap.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

/// The peak-hours heatmap: 7 weekdays × 24 hours.
///
/// Each cell is one hour bucket; the darker the cell, the busier the hour.
/// The grid MIRRORS in RTL: the first hour of a day sits on the right, the
/// weekday rows keep their top-to-bottom order.
class PeakHoursHeatmap extends StatelessWidget {
  const PeakHoursHeatmap({super.key, required this.cells});

  /// The buckets — `weekday` 0–6, `hour` 0–23.
  final List<HeatmapCell> cells;

  /// The number of weekday rows.
  static const int weekdayCount = 7;

  /// The number of hour columns.
  static const int hourCount = 24;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return Text(
        'dash_no_data_section'.tr(),
        style: TextStyles.font12DarkGray400Weight(context),
      );
    }

    final bySlot = <String, HeatmapCell>{
      for (final cell in cells) '${cell.weekday}_${cell.hour}': cell,
    };
    final peak = cells.fold<int>(
      0,
      (max, cell) => cell.orders > max ? cell.orders : max,
    );
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var weekday = 0; weekday < weekdayCount; weekday++)
          Padding(
            padding: EdgeInsets.only(bottom: 3.h),
            child: Row(
              children: [
                SizedBox(
                  width: 30.w,
                  child: Text(
                    _weekdayLabel(weekday, locale),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyles.font10DarkGray400Weight(context),
                  ),
                ),
                for (var hour = 0; hour < hourCount; hour++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                      child: _HeatCell(
                        key: ValueKey('dash_heatmap_${weekday}_$hour'),
                        intensity: _intensity(
                          bySlot['${weekday}_$hour']?.orders ?? 0,
                          peak,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(height: 4.h),
        Row(
          children: [
            SizedBox(width: 30.w),
            for (var hour = 0; hour < hourCount; hour++)
              Expanded(
                child: Center(
                  child: (hour % 6 == 0)
                      ? Text(
                          hour.toString().padLeft(2, '0'),
                          style: TextStyles.font10DarkGray400Weight(context),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// The share of the busiest hour this cell holds (0–1).
  static double _intensity(int orders, int peak) {
    if (peak <= 0 || orders <= 0) return 0;
    return (orders / peak).clamp(0.0, 1.0).toDouble();
  }

  /// The localized weekday abbreviation.
  static String _weekdayLabel(int weekday, String locale) {
    // 2026-10-18 is a Sunday — the reference week for the weekday names.
    final sunday = DateTime(2026, 10, 18).add(Duration(days: weekday));
    return DateFormat('EEE', locale).format(sunday);
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({super.key, required this.intensity});

  /// 0 (idle) – 1 (the busiest hour of the week).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            ColorsManager.primary100.withValues(alpha: 0.35),
            ColorsManager.primary500,
            intensity,
          ),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }
}
