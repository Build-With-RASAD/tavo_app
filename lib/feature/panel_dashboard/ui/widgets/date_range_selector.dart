// lib/feature/panel_dashboard/ui/widgets/date_range_selector.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

/// The window selector: today / 7 days / 30 days / this month / custom.
///
/// Picking a window refetches the heavy `/analytics` payload — the poll
/// never touches it.
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required this.range,
    this.onChanged,
    this.onCustomRange,
  });

  /// The window in force.
  final AnalyticsRange range;

  /// A window was picked.
  final void Function(AnalyticsRange range)? onChanged;

  /// A custom window was picked (inclusive bounds).
  final void Function(DateTime from, DateTime to)? onCustomRange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in AnalyticsRange.values)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: _RangeChip(
                keyId: option.name,
                label: option.labelKey.tr(),
                selected: option == range,
                onTap: () => _pick(context, option),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, AnalyticsRange option) async {
    if (option != AnalyticsRange.custom) {
      onChanged?.call(option);
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    onCustomRange?.call(picked.start, picked.end);
    onChanged?.call(AnalyticsRange.custom);
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.keyId,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// The stable id of the option (`today`, `last7Days`, …) — the key does
  /// NOT depend on the translated label, so it is stable in every locale.
  final String keyId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('dash_range_$keyId'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? ColorsManager.primary500 : ColorsManager.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? ColorsManager.primary500 : ColorsManager.grey100,
          ),
        ),
        child: Text(
          label,
          style: selected
              ? TextStyles.font12White500Weight(context)
              : TextStyles.font12DarkGray400Weight(context),
        ),
      ),
    );
  }
}
