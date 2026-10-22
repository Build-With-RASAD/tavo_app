// lib/feature/panel_dashboard/ui/widgets/alert_rail.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

/// The actionable alert rail: what needs a decision right now.
///
/// Every alert names the tab that RESOLVES it through its `action`, and
/// tapping it hands that action to the shell — the dashboard never ends in
/// a dead end.
class AlertRail extends StatelessWidget {
  const AlertRail({
    super.key,
    required this.alerts,
    this.onOpenAlert,
  });

  /// The alerts from the payload.
  final List<AnalyticsAlert> alerts;

  /// Opens the resolver for the tapped alert (its `action`).
  final void Function(String action)? onOpenAlert;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: ColorsManager.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: ColorsManager.grey100),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18.r,
              color: ColorsManager.success500,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'dash_no_alerts'.tr(),
                style: TextStyles.font12DarkGray400Weight(context),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final alert in alerts)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: InkWell(
              key: ValueKey('dash_alert_${alert.action}'),
              onTap:
                  onOpenAlert == null ? null : () => onOpenAlert!(alert.action),
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: ColorsManager.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: _accent(alert).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: _accent(alert).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        _icon(alert),
                        size: 16.r,
                        color: _accent(alert),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.message,
                            style: TextStyles.font12Black400Weight(context),
                          ),
                          if (alert.count > 0) ...[
                            SizedBox(height: 2.h),
                            Text(
                              '${alert.count}',
                              style: TextStyles.font10DarkGray400Weight(
                                context,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18.r,
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

  static Color _accent(AnalyticsAlert alert) {
    if (alert.isCritical) return ColorsManager.errorColor;
    if (alert.isWarning) return ColorsManager.secondary500;
    return ColorsManager.primary500;
  }

  static IconData _icon(AnalyticsAlert alert) {
    switch (alert.type) {
      case 'stock':
        return Icons.inventory_2_outlined;
      case 'waitlist':
        return Icons.queue_music_outlined;
      case 'orders':
        return Icons.receipt_long_outlined;
      case 'reservations':
        return Icons.event_seat_outlined;
      case 'tables':
        return Icons.table_chart_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }
}
