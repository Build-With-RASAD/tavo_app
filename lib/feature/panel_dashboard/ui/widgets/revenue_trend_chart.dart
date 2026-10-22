// lib/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/dashboard_format.dart';

/// The revenue trend — one line per day over the selected window.
///
/// The chart data is MEMOIZED: the same [LineChartData] instance is reused
/// while the series is unchanged, so a 20-second live poll (which does not
/// touch this series) never restarts the chart animation.
class RevenueTrendChart extends StatefulWidget {
  const RevenueTrendChart({super.key, required this.points});

  /// The daily series.
  final List<TrendPoint> points;

  @override
  State<RevenueTrendChart> createState() => _RevenueTrendChartState();
}

class _RevenueTrendChartState extends State<RevenueTrendChart> {
  List<TrendPoint>? _cachedPoints;
  LineChartData? _cachedData;
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
      height: 190.h,
      width: double.infinity,
      child: LineChart(
        data,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  LineChartData _dataFor(BuildContext context, Brightness brightness) {
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

  LineChartData _buildData(BuildContext context, List<TrendPoint> points) {
    final labelStyle = TextStyles.font10DarkGray400Weight(context);
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenueGross),
    ];
    final labelInterval = (points.length / 5).ceil().clamp(1, 30).toDouble();

    return LineChartData(
      minX: 0,
      // A single day must still give the chart a non-zero span — fl_chart
      // divides by it.
      maxX: points.length > 1 ? (points.length - 1).toDouble() : 1.0,
      minY: 0,
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
            reservedSize: 42,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                formatCompactMoney(value),
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
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touched) => [
            for (final spot in touched)
              LineTooltipItem(
                formatMoney(spot.y),
                TextStyles.font12Black500Weight(context),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: ColorsManager.primary500,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: ColorsManager.primary100.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  static bool _sameSeries(List<TrendPoint>? a, List<TrendPoint> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].date != b[i].date) return false;
      if (a[i].revenueGross != b[i].revenueGross) return false;
      if (a[i].orders != b[i].orders) return false;
    }
    return true;
  }
}
