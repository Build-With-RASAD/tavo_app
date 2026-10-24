// lib/feature/panel_dashboard/ui/widgets/occupancy_ring.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The table occupancy ring: how full the floor is right now.
///
/// Tapping it opens the tables tab — the number is a link into the screen
/// that acts on it, never a dead end.
///
/// The occupancy RULE (a table is occupied ⟺ it has an order whose status
/// is neither served nor cancelled) is computed server-side; the client
/// only renders the percentage it is given.
class OccupancyRing extends StatelessWidget {
  const OccupancyRing({
    super.key,
    required this.occupied,
    required this.total,
    this.onOpenTables,
  });

  final int occupied;
  final int total;
  final VoidCallback? onOpenTables;

  /// The share of occupied tables, clamped to 0–100.
  double get occupancyPct {
    if (total <= 0) return 0;
    return (occupied / total * 100).clamp(0.0, 100.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('dash_occupancy_ring'),
      onTap: onOpenTables,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: ColorsManager.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: ColorsManager.grey100),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72.r,
              height: 72.r,
              child: CustomPaint(
                painter: _RingPainter(progress: occupancyPct / 100),
                child: Center(
                  child: Text(
                    formatPercent(occupancyPct),
                    style: TextStyles.font14Black500Weight(context),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'dash_occupancy_title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.font14Black500Weight(context),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${formatCount(occupied)} / ${formatCount(total)}',
                    style: TextStyles.font12DarkGray400Weight(context),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_2,
              size: 18.r,
              color: ColorsManager.darkGray300,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

    canvas.drawArc(
      arcRect,
      -1.5708,
      6.2832,
      false,
      Paint()
        ..color = ColorsManager.grey100
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -1.5708,
      6.2832 * progress.clamp(0.0, 1.0).toDouble(),
      false,
      Paint()
        ..color = _colorFor(progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  static Color _colorFor(double progress) {
    if (progress >= 0.85) return ColorsManager.errorColor;
    if (progress >= 0.6) return ColorsManager.secondary500;
    return ColorsManager.success500;
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
