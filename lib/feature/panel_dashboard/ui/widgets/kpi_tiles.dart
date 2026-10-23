// lib/feature/panel_dashboard/ui/widgets/kpi_tiles.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/animation/primitives/spring_reveal.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The range-scoped KPI tiles.
///
/// Money is split three ways (spec decision 4): gross, net and tax are three
/// separate numbers, and promo credit is never counted as revenue. A metric
/// the backend could not compute (no qualifying row) renders as an em dash
/// rather than a fake zero.
class KpiTiles extends StatelessWidget {
  const KpiTiles({super.key, required this.kpi});

  /// The KPI payload.
  final AnalyticsKpi kpi;

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, String value, IconData icon})>[
      (
        label: 'dash_revenue_gross'.tr(),
        value: formatMoney(kpi.revenue.gross),
        icon: Icons.payments_outlined,
      ),
      (
        label: 'dash_revenue_net'.tr(),
        value: formatMoney(kpi.revenue.net),
        icon: Icons.account_balance_wallet_outlined,
      ),
      (
        label: 'dash_revenue_tax'.tr(),
        value: formatMoney(kpi.revenue.tax),
        icon: Icons.receipt_outlined,
      ),
      (
        label: 'dash_orders_total'.tr(),
        value: formatCount(kpi.orders.total),
        icon: Icons.shopping_bag_outlined,
      ),
      (
        label: 'dash_avg_order_value'.tr(),
        value: formatMoney(kpi.revenue.avgOrderValue),
        icon: Icons.local_activity_outlined,
      ),
      (
        label: 'dash_avg_prep_minutes'.tr(),
        value: _minutes(kpi.orders.avgPrepMinutes),
        icon: Icons.timer_outlined,
      ),
      (
        label: 'dash_reservations_total'.tr(),
        value: formatCount(kpi.reservations.total),
        icon: Icons.event_seat_outlined,
      ),
      (
        label: 'dash_no_show_rate'.tr(),
        value: _percent(kpi.reservations.noShowRate),
        icon: Icons.person_off_outlined,
      ),
      (
        label: 'dash_capacity_utilization'.tr(),
        value: _percent(kpi.reservations.capacityUtilizationPct),
        icon: Icons.event_available_outlined,
      ),
      (
        label: 'dash_customers_returning'.tr(),
        value: _percent(kpi.customers.returningPct),
        icon: Icons.people_outline,
      ),
      (
        label: 'dash_avg_rating'.tr(),
        value: kpi.avgRating?.toStringAsFixed(1) ?? '—',
        icon: Icons.star_outline,
      ),
      (
        label: 'dash_avg_ticket_minutes'.tr(),
        value: _minutes(kpi.avgTicketMinutes),
        icon: Icons.schedule_outlined,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10.w,
      crossAxisSpacing: 10.w,
      childAspectRatio: 2.4,
      children: [
        for (final (index, tile) in tiles.indexed)
          SpringRevealItem(
            index: index,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: ColorsManager.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: ColorsManager.grey100),
              ),
              child: Row(
                children: [
                  Icon(tile.icon, size: 18.r, color: ColorsManager.primary500),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tile.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.font10DarkGray400Weight(context),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          tile.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.font14Black500Weight(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _minutes(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} min';

  static String _percent(double? value) =>
      value == null ? '—' : formatPercent(value, fractionDigits: 1);
}
