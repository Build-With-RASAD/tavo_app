// lib/feature/panel_dashboard/ui/widgets/orders_volume_chart.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The orders volume — one bar per day over the selected window.
///
/// Like the revenue chart the data is MEMOIZED, so the live poll never
/// restarts the bar animation.
class OrdersVolumeChart extends StatefulWidget {
  const OrdersVolumeChart({super.key, required this.points});

  /// The daily series.
  final List<TrendPoint> points;

  @override
  State<OrdersVolumeChart> createState() => _OrdersVolumeChartState();
}

class _OrdersVolumeChartState extends State<OrdersVolumeChart> {
  List<TrendPoint>? _cachedPoints;
  BarChartData? _cachedData;
  Brightness? _cachedBrightness;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Text(
        'dash_no_data_section'.tr(),
        style: TextStyles.font12DarkGray400Weight(context),
      );
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final data = _dataFor(context, Theme.of(context).brightness);

    return SizedBox(
      height: 170.h,
      width: double.infinity,
      child: BarChart(
        data,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  BarChartData _dataFor(BuildContext context, Brightness brightness) {
    final cached = _cachedData;
    if (cached != null &&
        _cachedBrightness == brightness &&
        _sameSeries(_cachedPoints, widget.points)) {
      return cached;
    }
    final data = _buildData(context, widget.points);
    _cachedPoints = widget.points;
    _cachedData = data;
    _cachedBrightness = brightness;
    return data;
  }

  BarChartData _buildData(BuildContext context, List<TrendPoint> points) {
    final labelStyle = TextStyles.font10DarkGray400Weight(context);
    final labelInterval = (points.length / 5).ceil().clamp(1, 30).toDouble();

    final peak = points
        .map((point) => point.orders)
        .fold<int>(0, (max, value) => value > max ? value : max);
    final maxY = peak * 1.2;

    return BarChartData(
      // Never a zero span — fl_chart divides by it.
      maxY: maxY < 1 ? 1.0 : maxY,
      minY: 0,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: ColorsManager.grey100,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                formatCount(value.round()),
                style: labelStyle,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: labelInterval,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              if (index % labelInterval.round() != 0 &&
                  index != points.length - 1) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  formatDayLabel(points[index].date),
                  style: labelStyle,
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            formatCount(rod.toY.round()),
            TextStyles.font12Black500Weight(context),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < points.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].orders.toDouble(),
                width: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                color: ColorsManager.primary500,
              ),
            ],
          ),
      ],
    );
  }

  static bool _sameSeries(List<TrendPoint>? a, List<TrendPoint> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].date != b[i].date) return false;
      if (a[i].orders != b[i].orders) return false;
    }
    return true;
  }
}
