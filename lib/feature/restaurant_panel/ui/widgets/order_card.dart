// lib/feature/restaurant_panel/ui/widgets/order_card.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

/// One order row: number + status badge, customer line, an `N× item`
/// summary, total with a payment pill, and the status actions valid for the
/// row's current status.
///
/// Tapping the card (anywhere but a button) reports [onTap] so the screen
/// can open the details sheet; [onAction] receives the TARGET status from
/// `nextOrderActionsFor` — destructive targets are routed through an action
/// sheet by the caller, not handled here.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.acting,
    required this.onAction,
    required this.onTap,
  });

  final PanelOrder order;

  /// Whether THIS row's status action is in flight (shows spinners and
  /// disables every button on the row).
  final bool acting;

  /// Requests a transition to [String] (the target status).
  final ValueChanged<String> onAction;

  /// Opens the order details sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions = nextOrderActionsFor(order.orderStatus);
    final paymentKey = paymentStatusLabelKey(order.paymentStatus);
    final customer = [
      if (order.customerName.isNotEmpty) order.customerName,
      if (order.customerPhone.isNotEmpty) order.customerPhone,
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: ColorsManager.grey100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  StatusBadge(status: order.orderStatus),
                ],
              ),
              if (customer.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
              ],
              if (order.items.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  order.items
                      .map((line) => '${line.quantity}× ${line.name}')
                      .join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.font14Black400Weight(context),
                ),
              ],
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatOrderAmount(order.totalPrice)} ${'currency'.tr()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.font16Black500Weight(context),
                    ),
                  ),
                  if (paymentKey != null) ...[
                    SizedBox(width: 8.w),
                    StatusBadge(
                      status: order.paymentStatus,
                      label: paymentKey.tr(),
                    ),
                  ],
                ],
              ),
              if (actions.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) SizedBox(width: 8.w),
                      Expanded(child: _actionButton(context, actions[i])),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// One target of `nextOrderActionsFor`: `confirmed` → "Confirm",
  /// `cancelled` → "Cancel" (danger styling), everything else uses the
  /// status label itself. Disabled with a spinner while [acting].
  Widget _actionButton(BuildContext context, String target) {
    final danger = target == 'cancelled';

    return ElevatedButton(
      onPressed: acting ? null : () => onAction(target),
      style: ElevatedButton.styleFrom(
        backgroundColor: danger
            ? ColorsManager.redButton
            : ColorsManager.primaryColor,
        foregroundColor: danger ? ColorsManager.white : ColorsManager.black,
        minimumSize: Size(0, 40.h),
      ),
      child: acting
          ? SizedBox(
              width: 18.w,
              height: 18.h,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_actionLabel(target)),
    );
  }

  String _actionLabel(String target) {
    switch (target) {
      case 'confirmed':
        return 'confirm'.tr();
      case 'cancelled':
        return 'cancel'.tr();
      default:
        return orderStatusLabelKey(target).tr();
    }
  }
}

/// i18n key for a payment-state pill (`paid` → `payment_paid`); unknown
/// states return `null` so callers hide the pill rather than print a raw
/// key.
String? paymentStatusLabelKey(String paymentStatus) {
  switch (paymentStatus) {
    case 'paid':
    case 'unpaid':
    case 'failed':
    case 'refunded':
      return 'payment_$paymentStatus';
    default:
      return null;
  }
}

/// `400` → `400`, `1234.5` → `1,234.50` — thousands grouping for money
/// (same rules as the dashboard's revenue formatter).
String formatOrderAmount(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return _groupDigits(value.round());
  }
  final whole = _groupDigits(value.truncate());
  final cents = (value - value.truncate())
      .abs()
      .toStringAsFixed(2)
      .substring(2);
  return '$whole.$cents';
}

String _groupDigits(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
