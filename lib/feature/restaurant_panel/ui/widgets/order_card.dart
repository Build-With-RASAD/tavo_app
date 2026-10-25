// lib/feature/restaurant_panel/ui/widgets/order_card.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

/// One order row, built to answer the three questions service staff ask at a
/// glance: *where* is it going (`T1-1 · Terrace`), *how long* has it been
/// waiting (colour-coded timer) and *what is in it* (lines + guest notes).
///
/// The left accent bar repeats the status colour, so a long list can be
/// scanned vertically without reading a single badge.
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

  /// How many item lines the row shows before collapsing into `+N`.
  static const int _previewLines = 3;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions = nextOrderActionsFor(order.orderStatus);
    final paymentKey = paymentStatusLabelKey(order.paymentStatus);
    final accent = StatusBadge.colorFor(order.orderStatus);
    final minutes = order.minutesWaiting();
    final terminal = order.orderStatus == 'served' ||
        order.orderStatus == 'cancelled';
    final sourceKey = orderSourceLabelKey(order.source);
    final customer = [
      if (order.customerName.isNotEmpty) order.customerName,
      if (order.customerPhone.isNotEmpty) order.customerPhone,
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.r),
        side: const BorderSide(color: ColorsManager.grey100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4.w, color: accent),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 14.w, 12.h),
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
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          StatusBadge(status: order.orderStatus),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (order.tableCode.isNotEmpty)
                            _MetaChip(
                              icon: Iconsax.location,
                              label: order.zone.isEmpty
                                  ? order.tableCode
                                  : '${order.tableCode} · ${order.zone}',
                              emphasis: true,
                            ),
                          if (order.guestCount > 0)
                            _MetaChip(
                              icon: Iconsax.people,
                              label: order.tableSeats > 0
                                  ? '${order.guestCount} / ${order.tableSeats}'
                                  : '${order.guestCount}',
                              danger: order.tableSeats > 0 &&
                                  order.guestCount > order.tableSeats,
                            ),
                          if (sourceKey.isNotEmpty)
                            _MetaChip(
                              icon: Iconsax.scan,
                              label: sourceKey.tr(),
                            ),
                          if (!terminal)
                            _MetaChip(
                              icon: Iconsax.clock,
                              label: formatElapsed(minutes),
                              color: _timerColor(minutes),
                              emphasis: true,
                            ),
                        ],
                      ),
                      if (customer.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.font12DarkGray400Weight(context),
                        ),
                      ],
                      if (order.items.isNotEmpty) ...[
                        SizedBox(height: 10.h),
                        for (final line in order.items.take(_previewLines))
                          Padding(
                            padding: EdgeInsets.only(bottom: 4.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22.w,
                                  height: 22.w,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: ColorsManager.grey100,
                                    borderRadius: BorderRadius.circular(7.r),
                                  ),
                                  child: Text(
                                    '${line.quantity}',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyles.font14Black400Weight(
                                          context,
                                        ),
                                      ),
                                      if (line.note.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2.h),
                                          child: Text(
                                            line.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyles.font12DarkGray400Weight(
                                              context,
                                            ).copyWith(
                                              color: const Color(0xFF8D6E00),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  formatOrderAmount(line.lineTotal),
                                  style: TextStyles.font12DarkGray400Weight(
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (order.items.length > _previewLines)
                          Text(
                            '+${order.items.length - _previewLines}',
                            style: TextStyles.font12DarkGray400Weight(context),
                          ),
                      ],
                      if (order.notes.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        _GuestNote(text: order.notes),
                      ],
                      SizedBox(height: 10.h),
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
                              Expanded(
                                child: _actionButton(context, actions[i]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Green under 10 minutes, amber under 20, red after — the same thresholds
  /// the kitchen display uses for "late".
  Color _timerColor(int minutes) {
    if (minutes >= 20) return const Color(0xFFC62828);
    if (minutes >= 10) return const Color(0xFFF9A825);
    return const Color(0xFF22A83A);
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

/// A small fact about the order: table, party, channel or elapsed time.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasis = false,
    this.danger = false,
    this.color,
  });

  final IconData icon;
  final String label;

  /// Draws the chip on the gold-tinted surface instead of the neutral one.
  final bool emphasis;

  /// Draws the chip in danger red (an overfull party).
  final bool danger;

  /// Overrides the foreground colour (the elapsed-time heat).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = danger
        ? const Color(0xFFC62828)
        : color ?? ColorsManager.darkGray;
    final background = danger
        ? const Color(0xFFFDECEA)
        : emphasis
            ? ColorsManager.primaryColor.withValues(alpha: 0.12)
            : ColorsManager.grey100;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: foreground),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The guest's own words — visually separate from the item list so an allergy
/// note never gets lost between two line items.
class _GuestNote extends StatelessWidget {
  const _GuestNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10.r),
        border: const Border(
          left: BorderSide(color: ColorsManager.primaryColor, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.note_1, size: 14, color: Color(0xFF8D6E00)),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF6B5200),
              ),
            ),
          ),
        ],
      ),
    );
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
