// lib/feature/panel_dashboard/ui/widgets/orders_summary.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/text_styles.dart';

/// Order counts by status as tappable chips. Tapping a chip hands the status
/// to [onOpenOrders] — the orders-tab deep link itself is controller-owned
/// (reported diff, not built here). Labels reuse the shared status keys
/// (`pending` … `served`, `cancelled`).
class OrdersSummary extends StatelessWidget {
  const OrdersSummary({
    super.key,
    required this.ordersByStatus,
    this.onOpenOrders,
  });

  final Map<String, int> ordersByStatus;
  final void Function(String status)? onOpenOrders;

  /// Fixed status order first, then any unknown statuses alphabetically.
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
    final rest = counts.keys.where((s) => !order.contains(s)).toList()
      ..sort();
    return [...known, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final statuses = orderedStatuses(ordersByStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dash_orders_title'.tr(),
          style: TextStyles.font16Black500Weight(context),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final status in statuses)
              ActionChip(
                key: ValueKey('orders_chip_$status'),
                label: Text('${status.tr()} · ${ordersByStatus[status]}'),
                onPressed: onOpenOrders == null
                    ? null
                    : () => onOpenOrders!(status),
              ),
          ],
        ),
      ],
    );
  }
}
