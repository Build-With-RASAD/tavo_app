// lib/feature/panel_dashboard/ui/widgets/live_hero_band.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The "Now" band: what is happening in the venue RIGHT NOW.
///
/// Revenue today, open orders, table occupancy and the waitlist — each a
/// link into the tab that acts on it. The band carries the live pulse and a
/// delta chip against the previous period.
///
/// The numbers animate (a count-up and a pulse) but the animations are
/// ONE-SHOT: they restart on every live update and then stop, so a
/// 20-second poll never keeps the frame scheduler busy. Under reduced
/// motion they collapse to their final frame.
class LiveHeroBand extends StatefulWidget {
  const LiveHeroBand({
    super.key,
    required this.live,
    this.sparkline = const [],
    this.revenueDeltaPct,
    this.onOpenOrders,
    this.onOpenWaitlist,
    this.onOpenTables,
  });

  /// The polled snapshot.
  final LiveSnapshot live;

  /// The daily revenue series behind the sparkline (range-scoped, so it does
  /// NOT change between two polls).
  final List<TrendPoint> sparkline;

  /// The revenue delta against the previous period — null when there is no
  /// previous period to compare with.
  final double? revenueDeltaPct;

  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenWaitlist;
  final VoidCallback? onOpenTables;

  @override
  State<LiveHeroBand> createState() => _LiveHeroBandState();
}

class _LiveHeroBandState extends State<LiveHeroBand> {
  int _tick = 0;

  @override
  void didUpdateWidget(covariant LiveHeroBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new snapshot restarts the pulse — one extra animation per poll.
    if (!identical(oldWidget.live, widget.live)) _tick++;
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: ColorsManager.primary500,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LivePulse(key: ValueKey('dash_live_pulse_$_tick')),
              SizedBox(width: 6.w),
              Text(
                'dash_live'.tr(),
                style: TextStyles.font12White500Weight(context),
              ),
              const Spacer(),
              if (widget.revenueDeltaPct != null)
                _DeltaChip(deltaPct: widget.revenueDeltaPct!),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _CountUp(
                  value: live.revenueToday,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  builder: (value) => Text(
                    formatMoney(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.font24White500Weight(context),
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  'currency'.tr(),
                  style: TextStyles.font12White500Weight(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'dash_revenue_today'.tr(),
            style: TextStyles.font12White400Weight(context),
          ),
          SizedBox(height: 12.h),
          _Sparkline(
            values: [
              for (final point in widget.sparkline) point.revenueGross,
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _LiveTile(
                  label: 'dash_open_orders'.tr(),
                  value: formatCount(live.openOrders),
                  icon: Icons.receipt_long_outlined,
                  onTap: widget.onOpenOrders,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _LiveTile(
                  label: 'dash_occupancy'.tr(),
                  value: formatPercent(live.occupancyPct),
                  icon: Icons.table_chart_outlined,
                  onTap: widget.onOpenTables,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _LiveTile(
                  label: 'dash_waitlist_count'.tr(),
                  value: formatCount(live.waitlistCount),
                  icon: Icons.queue_music_outlined,
                  onTap: widget.onOpenWaitlist,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pulsing "live" dot. One shot per update, then it rests.
class _LivePulse extends StatelessWidget {
  const _LivePulse({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0.25),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, value, _) => Container(
        width: 10.r,
        height: 10.r,
        decoration: BoxDecoration(
          color: ColorsManager.success400.withValues(alpha: value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The headline number: it counts up to its new value.
class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.duration,
    required this.builder,
  });

  final double value;
  final Duration duration;
  final Widget Function(double value) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => builder(animated),
    );
  }
}

/// The delta chip — up / down / flat, never a fake number.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.deltaPct});

  final double deltaPct;

  @override
  Widget build(BuildContext context) {
    final up = deltaPct > 0;
    final flat = deltaPct == 0;
    final color = flat
        ? ColorsManager.white
        : up
            ? ColorsManager.success400
            : ColorsManager.errorColor;
    return Container(
      key: const ValueKey('dash_live_delta'),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: ColorsManager.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flat
                ? Icons.remove
                : up
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
            size: 12.r,
            color: color,
          ),
          SizedBox(width: 2.w),
          Text(
            formatDelta(deltaPct),
            style: TextStyles.font12White500Weight(context).copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable live figure.
class _LiveTile extends StatelessWidget {
  const _LiveTile({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: ColorsManager.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16.r, color: ColorsManager.white),
            SizedBox(height: 4.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.font16White500Weight(context),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.font12White400Weight(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The revenue sparkline — hand-drawn so a poll never re-animates a chart.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: 28.h,
        child: Center(
          child: Text(
            'dash_no_data_section'.tr(),
            style: TextStyles.font12White400Weight(context),
          ),
        ),
      );
    }
    return SizedBox(
      height: 28.h,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var max = values.first;
    var min = values.first;
    for (final value in values) {
      if (value > max) max = value;
      if (value < min) min = value;
    }
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;
    final step = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height - ((values[i] - min) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = ColorsManager.white.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ColorsManager.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
