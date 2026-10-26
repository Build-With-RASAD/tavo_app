// lib/feature/restaurant_panel/ui/widgets/order_card.dart
//
// One order row, built to answer the three questions service staff ask at a
// glance: *where* is it going (`T1-1 · Terrace`), *how long* has it been
// waiting (colour-coded timer) and *what is in it* (lines + guest notes).
//
// The leading accent bar repeats the status colour, so a long list can be
// scanned vertically without reading a single badge. It sits on the leading
// edge, so RTL flips it without any extra work.

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

/// Status → kit tone. Mirrors [StatusBadge.colorFor] so an order never looks
/// one colour on the board and another in the kitchen display.
TavoTone orderStatusTone(String status) {
  switch (status) {
    case 'confirmed':
    case 'completed':
    case 'served':
    case 'paid':
      return TavoTone.success;
    case 'seated':
    case 'preparing':
    case 'ready':
    case 'refunded':
      return TavoTone.info;
    case 'cancelled':
    case 'no_show':
    case 'failed':
      return TavoTone.danger;
    default:
      // pending, unpaid and anything the backend adds later.
      return TavoTone.warning;
  }
}

/// Solid hue for a tone — used for the accent bar and the timer, where a
/// tinted surface would disappear against the card.
Color orderToneColor(TavoTone tone) => switch (tone) {
      TavoTone.success => TavoColors.success,
      TavoTone.info => TavoColors.info,
      TavoTone.danger => TavoColors.danger,
      TavoTone.warning => TavoColors.warning,
      TavoTone.brand => TavoColors.brand700,
      TavoTone.neutral => TavoColors.mutedForeground,
    };

/// One order row.
///
/// Tapping anywhere but a button reports [onTap] so the screen can open the
/// details sheet; [onAction] receives the TARGET status from
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
    final List<String> actions = nextOrderActionsFor(order.orderStatus);
    final String? paymentKey = paymentStatusLabelKey(order.paymentStatus);
    final TavoTone tone = orderStatusTone(order.orderStatus);
    final int minutes = order.minutesWaiting();
    final bool terminal =
        order.orderStatus == 'served' || order.orderStatus == 'cancelled';
    final String sourceKey = orderSourceLabelKey(order.source);
    final String customer = <String>[
      if (order.customerName.isNotEmpty) order.customerName,
      if (order.customerPhone.isNotEmpty) order.customerPhone,
    ].join(' • ');

    return TavoCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The status rail: three pixels that let a manager read the board
            // from across the room.
            Container(width: 3, color: orderToneColor(tone)),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TavoSpace.md,
                  TavoSpace.md,
                  TavoSpace.md,
                  TavoSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TavoType.title.copyWith(
                              fontFeatures: TavoType.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: TavoSpace.sm),
                        TavoStatusPill(
                          label: order.orderStatus.tr(),
                          tone: tone,
                          size: TavoPillSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: TavoSpace.sm),
                    Wrap(
                      spacing: TavoSpace.xs,
                      runSpacing: TavoSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
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
                    if (customer.isNotEmpty) ...<Widget>[
                      const SizedBox(height: TavoSpace.xs),
                      Text(
                        customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavoType.micro.copyWith(
                          color: TavoColors.mutedForeground,
                        ),
                      ),
                    ],
                    if (order.items.isNotEmpty) ...<Widget>[
                      const SizedBox(height: TavoSpace.sm),
                      for (final OrderLine line in order.items.take(_previewLines))
                        Padding(
                          padding: const EdgeInsets.only(bottom: TavoSpace.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: TavoColors.muted,
                                  borderRadius:
                                      BorderRadius.circular(TavoRadii.sm),
                                ),
                                child: Text(
                                  '${line.quantity}',
                                  style: TavoType.micro.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: TavoType.tabular,
                                  ),
                                ),
                              ),
                              const SizedBox(width: TavoSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      line.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TavoType.bodySmall,
                                    ),
                                    if (line.note.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          line.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TavoType.micro.copyWith(
                                            color: TavoColors.brand800,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: TavoSpace.sm),
                              Text(
                                formatOrderAmount(line.lineTotal),
                                style: TavoType.micro.copyWith(
                                  color: TavoColors.mutedForeground,
                                  fontFeatures: TavoType.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (order.items.length > _previewLines)
                        Text(
                          '+${order.items.length - _previewLines}',
                          style: TavoType.micro.copyWith(
                            color: TavoColors.mutedForeground,
                          ),
                        ),
                    ],
                    if (order.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: TavoSpace.sm),
                      _GuestNote(text: order.notes),
                    ],
                    const SizedBox(height: TavoSpace.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${formatOrderAmount(order.totalPrice)} '
                            '${'currency'.tr()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TavoType.title.copyWith(
                              fontFeatures: TavoType.tabular,
                            ),
                          ),
                        ),
                        if (paymentKey != null) ...<Widget>[
                          const SizedBox(width: TavoSpace.sm),
                          TavoStatusPill(
                            label: paymentKey.tr(),
                            tone: orderStatusTone(order.paymentStatus),
                            size: TavoPillSize.small,
                          ),
                        ],
                      ],
                    ),
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: TavoSpace.sm),
                      Row(
                        children: <Widget>[
                          for (int i = 0; i < actions.length; i++) ...<Widget>[
                            if (i > 0) const SizedBox(width: TavoSpace.sm),
                            Expanded(
                              child: _actionButton(actions[i]),
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
    );
  }

  /// Green under 10 minutes, amber under 20, red after — the same thresholds
  /// the kitchen display uses for "late".
  Color _timerColor(int minutes) {
    if (minutes >= 20) return TavoColors.danger;
    if (minutes >= 10) return TavoColors.warning;
    return TavoColors.success;
  }

  /// One target of `nextOrderActionsFor`: `confirmed` → "Confirm",
  /// `cancelled` → "Cancel" (destructive styling), everything else uses the
  /// status label itself. Disabled with a spinner while [acting].
  Widget _actionButton(String target) {
    final bool danger = target == 'cancelled';
    final String label = _actionLabel(target);

    if (danger) {
      return TavoButton.destructive(
        label: label,
        size: TavoButtonSize.compact,
        expand: true,
        isLoading: acting,
        onPressed: acting ? null : () => onAction(target),
      );
    }
    return TavoButton.primary(
      label: label,
      size: TavoButtonSize.compact,
      expand: true,
      isLoading: acting,
      onPressed: acting ? null : () => onAction(target),
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
    final Color foreground =
        danger ? TavoColors.danger : (color ?? TavoColors.mutedForeground);
    final Color background = danger
        ? TavoColors.danger.withValues(alpha: 0.10)
        : emphasis
            ? TavoColors.brand500.withValues(alpha: 0.14)
            : TavoColors.muted;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavoSpace.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TavoType.micro.copyWith(
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavoSpace.sm,
        vertical: TavoSpace.xs,
      ),
      decoration: BoxDecoration(
        color: TavoColors.goldTint,
        borderRadius: BorderRadius.circular(TavoRadii.md),
        // The rule follows the reading direction: leading edge, not `left`.
        border: BorderDirectional(
          start: BorderSide(color: TavoColors.brand500, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Iconsax.note_1, size: 14, color: TavoColors.brand800),
          const SizedBox(width: TavoSpace.xs),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TavoType.micro.copyWith(
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: TavoColors.brand900,
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
