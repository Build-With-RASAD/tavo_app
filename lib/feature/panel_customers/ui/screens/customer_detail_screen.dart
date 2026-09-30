// lib/feature/panel_customers/ui/screens/customer_detail_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/panel_customers/data/model/customer_models.dart';

/// `32.0` → `32`, `32.5` → `32.5` — whole totals read without the `.0`.
String formatCustomerTotal(double total) =>
    total == total.roundToDouble() ? '${total.round()}' : '$total';

/// Read-only customer profile + capped order / reservation histories.
///
/// Takes the loaded [detail] directly — the list screen awaits the detail
/// cubit before pushing, so this screen has no loading state. History rows
/// stay raw backend maps rendered with `??` fallbacks (no second model
/// layer).
class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.detail});

  final PanelCustomerDetail detail;

  @override
  Widget build(BuildContext context) {
    final profile = detail.profile;
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _ProfileHeader(profile: profile),
          SizedBox(height: 20.h),
          Text(
            'order_history'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          if (detail.orders.isEmpty)
            EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'no_orders'.tr(),
            )
          else
            for (final order in detail.orders)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _OrderCard(order: order),
              ),
          SizedBox(height: 12.h),
          Text(
            'reservation_history'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          if (detail.reservations.isEmpty)
            EmptyStateView(
              icon: Icons.event_outlined,
              title: 'no_reservations'.tr(),
            )
          else
            for (final reservation in detail.reservations)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _ReservationCard(reservation: reservation),
              ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final PanelCustomer profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(profile.phone, style: textTheme.bodyMedium),
          if (profile.email != null && profile.email!.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(profile.email!, style: textTheme.bodyMedium),
          ],
          SizedBox(height: 8.h),
          Text(
            '${profile.orderCount} · ${profile.reservationCount}',
            style: textTheme.bodySmall,
          ),
          SizedBox(height: 4.h),
          Text(
            '${'total_spent'.tr()}: ${formatCustomerTotal(profile.totalSpent)}',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (profile.lastOrderAt != null &&
              profile.lastOrderAt!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              '${'last_order'.tr()}: ${profile.lastOrderAt}',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = order['orderStatus'] as String? ?? '';
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order['orderNumber'] as String? ?? '',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${order['totalPrice'] ?? ''}',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              if (status.isNotEmpty) StatusBadge(status: status),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  order['createdAt'] as String? ?? '',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation});

  final Map<String, dynamic> reservation;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = reservation['status'] as String? ?? '';
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reservation['startAt'] as String? ?? '',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              if (status.isNotEmpty) StatusBadge(status: status),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${reservation['guestsCount'] ?? ''}',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
