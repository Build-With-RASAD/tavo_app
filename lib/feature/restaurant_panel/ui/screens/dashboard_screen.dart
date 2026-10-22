// lib/feature/restaurant_panel/ui/screens/dashboard_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/alert_rail.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/comparison_row.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/date_range_selector.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/kpi_tiles.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/live_hero_band.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/management_shortcuts.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/occupancy_ring.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/order_pipeline.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/orders_volume_chart.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/peak_hours_heatmap.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/revenue_trend_chart.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/section_error_boundary.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/top_items_chart.dart';

/// The staff panel home — a full restaurant management system in ONE scroll
/// view, split into three zones (spec decision 1):
///
///   * **Now** — what is happening right now: revenue today, open orders,
///     table occupancy and the waitlist, with a sparkline, a live pulse and
///     a delta chip against the previous period.
///   * **Ops** — the order pipeline, the occupancy ring, the actionable
///     alert rail and the management shortcuts.
///   * **Business** — the range selector, the KPI tiles, the revenue and
///     volume charts, the peak-hours heatmap, the best sellers and the
///     period comparison.
///
/// EVERY headline number is a link into the tab that acts on it — there are
/// no dead ends on this screen.
///
/// Two cadences: the heavy `/analytics` payload is read on a range change
/// and on pull-to-refresh; the cheap `/analytics/live` snapshot is polled
/// every 20 seconds and MERGED into the page, so the screen never flashes
/// empty between two ticks.
///
/// Every section renders its own inline error + retry
/// ([SectionErrorBoundary]): one failing read never blanks the page.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    this.onNewOrder,
    this.onOpenOrders,
    this.onOpenWaitlist,
    this.onOpenReservations,
    this.onOpenHub,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  /// Dashboard shortcuts — tab switches / create-flow entry are shell-owned.
  final VoidCallback? onNewOrder;

  /// Opens the orders tab, optionally filtered by [status] (`null` = every
  /// order — the open-orders figure spans four statuses, so it opens the
  /// tab unfiltered; the pipeline carries the exact per-status links).
  final void Function(String? status)? onOpenOrders;

  /// Opens the waitlist tab.
  final VoidCallback? onOpenWaitlist;

  /// Opens the reservations tab.
  final VoidCallback? onOpenReservations;

  /// Opens a More-hub screen by its registry id (`menu`, `tables`, …).
  final void Function(String hubId)? onOpenHub;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>(param1: restaurantId)..load(),
      child: _DashboardView(
        restaurantId: restaurantId,
        venue: venue,
        onNewOrder: onNewOrder,
        onOpenOrders: onOpenOrders,
        onOpenWaitlist: onOpenWaitlist,
        onOpenReservations: onOpenReservations,
        onOpenHub: onOpenHub,
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView({
    required this.restaurantId,
    required this.venue,
    this.onNewOrder,
    this.onOpenOrders,
    this.onOpenWaitlist,
    this.onOpenReservations,
    this.onOpenHub,
  });

  final String restaurantId;
  final StaffRestaurant venue;
  final VoidCallback? onNewOrder;
  final void Function(String? status)? onOpenOrders;
  final VoidCallback? onOpenWaitlist;
  final VoidCallback? onOpenReservations;
  final void Function(String hubId)? onOpenHub;

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  /// The live poll cadence (spec decision 2: the cheap endpoint only).
  static const Duration _pollInterval = Duration(seconds: 20);

  late final DashboardCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<DashboardCubit>();
    _cubit.startLivePolling(_pollInterval);
  }

  @override
  void dispose() {
    _cubit.stopLivePolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardInitial || state is DashboardLoading) {
          return const Scaffold(body: ListSkeleton());
        }
        if (state is DashboardError) {
          return Scaffold(
            body: ErrorStateView(
              message: state.message,
              onRetry: () => _cubit.load(),
            ),
          );
        }
        final loaded = state as DashboardLoaded;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () => _cubit.refresh(),
            child: _buildContent(context, loaded),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, DashboardLoaded state) {
    final analytics = state.analytics;
    final live = state.live ?? const LiveSnapshot();

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        _buildHeader(context),
        SizedBox(height: 16.h),

        // ===================== NOW =====================
        _ZoneTitle(label: 'dash_zone_now'.tr()),
        SizedBox(height: 8.h),
        SectionErrorBoundary(
          error: state.liveError,
          onRetry: () => _cubit.refreshLive(),
          builder: (context) => LiveHeroBand(
            live: live,
            sparkline: analytics?.trend.daily ?? const [],
            revenueDeltaPct: analytics?.comparison.revenue.deltaPct,
            onOpenOrders: () => widget.onOpenOrders?.call(null),
            onOpenWaitlist: widget.onOpenWaitlist,
            onOpenTables: () => widget.onOpenHub?.call('tables'),
          ),
        ),
        SizedBox(height: 10.h),
        SectionErrorBoundary(
          builder: (context) => OutlinedButton.icon(
            key: const ValueKey('dash_quick_new_order'),
            onPressed: widget.onNewOrder,
            icon: const Icon(Icons.add_business_outlined),
            label: Text('dash_quick_order'.tr()),
          ),
        ),
        SizedBox(height: 20.h),

        // ===================== OPS =====================
        _ZoneTitle(label: 'dash_zone_ops'.tr()),
        SizedBox(height: 8.h),
        SectionErrorBoundary(
          builder: (context) => _Card(
            title: 'dash_pipeline_title'.tr(),
            child: OrderPipeline(
              ordersByStatus: live.ordersByStatus,
              onOpenOrders: (status) => widget.onOpenOrders?.call(status),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SectionErrorBoundary(
          builder: (context) => OccupancyRing(
            occupied: live.occupiedTables,
            total: live.totalTables,
            onOpenTables: () => widget.onOpenHub?.call('tables'),
          ),
        ),
        SizedBox(height: 10.h),
        SectionErrorBoundary(
          builder: (context) => _Card(
            title: 'dash_alerts_title'.tr(),
            child: AlertRail(
              alerts: analytics?.alerts ?? const [],
              onOpenAlert: _openAlert,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SectionErrorBoundary(
          builder: (context) => _Card(
            title: 'dash_shortcuts_title'.tr(),
            child: ManagementShortcuts(onOpenHub: widget.onOpenHub),
          ),
        ),
        SizedBox(height: 20.h),

        // ===================== BUSINESS =====================
        _ZoneTitle(label: 'dash_zone_business'.tr()),
        SizedBox(height: 8.h),
        DateRangeSelector(
          range: state.range,
          onChanged: (range) => _cubit.setRange(range),
          onCustomRange: (from, to) =>
              _cubit.setRange(AnalyticsRange.custom, from: from, to: to),
        ),
        if (state.refreshing) ...[
          SizedBox(height: 8.h),
          const LinearProgressIndicator(minHeight: 2),
        ],
        SizedBox(height: 10.h),
        SectionErrorBoundary(
          error: state.analyticsError,
          onRetry: () => _cubit.refresh(),
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_kpi_title'.tr(),
                  child: KpiTiles(kpi: analytics?.kpi ?? const AnalyticsKpi()),
                ),
              ),
              SizedBox(height: 10.h),
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_trend_title'.tr(),
                  child: RevenueTrendChart(
                    points: analytics?.trend.daily ?? const [],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_volume_title'.tr(),
                  child: OrdersVolumeChart(
                    points: analytics?.trend.daily ?? const [],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_heatmap_title'.tr(),
                  child: PeakHoursHeatmap(
                    cells: analytics?.trend.heatmap ?? const [],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_top_items_title'.tr(),
                  child: TopItemsChart(items: analytics?.topItems ?? const []),
                ),
              ),
              SizedBox(height: 10.h),
              SectionErrorBoundary(
                builder: (context) => _Card(
                  title: 'dash_comparison_title'.tr(),
                  child: ComparisonRow(
                    comparison:
                        analytics?.comparison ?? const AnalyticsComparison(),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  /// An alert names the tab that RESOLVES it through its `action`
  /// (the backend emits `orders`, `reservations`, `waitlist`, `reports`).
  void _openAlert(String action) {
    switch (action) {
      case 'orders':
        widget.onOpenOrders?.call(null);
        return;
      case 'reservations':
        widget.onOpenReservations?.call();
        return;
      case 'waitlist':
        widget.onOpenWaitlist?.call();
        return;
      case 'tables':
        widget.onOpenHub?.call('tables');
        return;
      default:
        // `reports` has no hub screen yet — the shell falls back to the More
        // tab rather than swallowing the tap.
        widget.onOpenHub?.call(action);
    }
  }

  Widget _buildHeader(BuildContext context) {
    final locale = context.locale.languageCode;
    return Row(
      children: [
        Container(
          width: 44.r,
          height: 44.r,
          decoration: BoxDecoration(
            color: ColorsManager.primary100,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.restaurant,
            size: 22.r,
            color: ColorsManager.primary500,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.venue.displayName(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.font20Black500Weight(context),
              ),
              SizedBox(height: 2.h),
              Text(
                'dashboard'.tr(),
                style: TextStyles.font14DarkGray400Weight(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The title of a zone.
class _ZoneTitle extends StatelessWidget {
  const _ZoneTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyles.font16Black500Weight(context),
    );
  }
}

/// A white card around one section.
class _Card extends StatelessWidget {
  const _Card({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyles.font14Black500Weight(context),
            ),
            SizedBox(height: 10.h),
          ],
          child,
        ],
      ),
    );
  }
}
