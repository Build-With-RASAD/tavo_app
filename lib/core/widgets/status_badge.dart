// lib/core/widgets/status_badge.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared pill badge for any status string — order statuses, payment states
/// and (per Task 11) reservation statuses.
///
/// The label defaults to `status.tr()` because every status in this app
/// doubles as its translation key; pass [label] when the visible wording
/// differs (e.g. a `paid` payment shown as `payment_paid` → "Paid").
///
/// Colours come from [colorFor]: green = done/confirmed, blue = in progress,
/// red = failed/cancelled, amber = pending/unknown. Unknown statuses fall
/// back to the amber pair so a new backend status still reads as "active",
/// never as an invisible or broken chip.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  /// The status string itself (`pending`, `ready`, `cancelled`, `paid`, …).
  final String status;

  /// Overrides the displayed text; `null` shows `status.tr()`.
  final String? label;

  /// Foreground colour for [status] with a safe amber default for anything
  /// unknown — mirrors the legacy `_StatusBadge` palette in
  /// `restaurant_home_screen.dart` (extracted here so every tab can share
  /// one source of truth).
  static Color colorFor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
      case 'delivered':
      case 'paid':
        return const Color(0xFF22A83A);
      case 'seated':
      case 'preparing':
      case 'ready':
      case 'refunded':
        return const Color(0xFF1565C0);
      case 'cancelled':
      case 'no_show':
      case 'failed':
        return const Color(0xFFC62828);
      default:
        // pending, unpaid and anything the backend adds later.
        return const Color(0xFFF9A825);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label ?? status.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
