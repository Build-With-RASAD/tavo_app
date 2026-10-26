// lib/feature/panel_tables/ui/widgets/tables_widgets.dart
//
// Presentational pieces of the tables control room. Everything here is dumb:
// it receives data and callbacks, never a cubit, so each piece can be tested
// (and later re-skinned by the shared design kit) in isolation.
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';

import '../../data/model/floor_models.dart';
import '../../data/model/table_models.dart';

/// Semantic state colours. One palette, used by the pill, the tile, the row
/// and the sheet — a table can never be amber here and green there.
class TableColors {
  const TableColors._();

  // The floor's semantic states, resolved to the kit's palette so a table is
  // never amber here and gold there. Availability is the one state that must
  // read as "go" at a glance, so it uses the kit's success green.
  static const available = TavoColors.success;
  static const occupied = TavoColors.warning;
  static const reserved = TavoColors.info;
  static const inactive = TavoColors.mutedForeground;
  static const attention = TavoColors.destructiveSolid;
  static const ink = TavoColors.foreground;
  static const inkSoft = TavoColors.mutedForeground;
  static const canvas = TavoColors.muted;
  static const line = TavoColors.border;
  static const gold = TavoColors.brand500;
  static const goldDark = TavoColors.foreground;

  static Color of(String status) {
    switch (status) {
      case 'occupied':
        return occupied;
      case 'reserved':
        return reserved;
      case 'inactive':
        return inactive;
      default:
        return available;
    }
  }

  /// Same states, as the kit's pill tones.
  static TavoTone toneOf(String status) {
    switch (status) {
      case 'occupied':
        return TavoTone.warning;
      case 'reserved':
        return TavoTone.info;
      case 'inactive':
        return TavoTone.neutral;
      default:
        return TavoTone.success;
    }
  }
}

String floorStatusLabel(String status) => switch (status) {
  'occupied' => 'status_occupied'.tr(),
  'reserved' => 'status_reserved'.tr(),
  'inactive' => 'status_inactive'.tr(),
  _ => 'status_available'.tr(),
};

String requestLabel(String type) => switch (type) {
  'bill' => 'request_bill'.tr(),
  'card_machine' => 'request_card_machine'.tr(),
  _ => 'request_waiter'.tr(),
};

IconData requestIcon(String type) => switch (type) {
  'bill' => Iconsax.receipt_2,
  'card_machine' => Iconsax.card,
  _ => Iconsax.people,
};

String orderStatusLabel(String status) => switch (status) {
  'draft' => 'status_draft'.tr(),
  'pending' => 'status_pending'.tr(),
  'confirmed' => 'status_confirmed'.tr(),
  'preparing' => 'status_preparing'.tr(),
  'ready' => 'status_ready'.tr(),
  'served' => 'status_served'.tr(),
  'cancelled' => 'status_cancelled'.tr(),
  _ => status,
};

/// Small, quiet pill used everywhere a status appears.
class TableStatusPill extends StatelessWidget {
  const TableStatusPill({
    super.key,
    required this.status,
    this.label,
    this.compact = false,
  });

  final String status;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TavoStatusPill(
      label: label ?? floorStatusLabel(status),
      tone: TableColors.toneOf(status),
      size: compact ? TavoPillSize.small : TavoPillSize.regular,
    );
  }
}

/// One tile in the today strip. `dark` is the sales tile: the only money-only
/// tile, so it gets the weight.
class _TodayTile extends StatelessWidget {
  const _TodayTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.icon,
    this.onTap,
    this.dark = false,
    this.progress,
  });

  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool dark;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : TableColors.ink;
    final soft = dark
        ? Colors.white.withValues(alpha: 0.62)
        : TableColors.inkSoft;
    return Material(
      color: dark ? TableColors.goldDark : Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: 150.w,
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : TableColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 13.sp,
                      color: dark ? TableColors.gold : soft,
                    ),
                    SizedBox(width: 5.w),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.75)
                            : soft,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dark ? 23.sp : 20.sp,
                  fontWeight: FontWeight.w700,
                  color: dark ? TableColors.gold : fg,
                  height: 1.05,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (sub != null) ...[
                SizedBox(height: 3.h),
                Text(
                  sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.sp, color: soft),
                ),
              ],
              if (progress != null) ...[
                SizedBox(height: 7.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation(
                      dark ? TableColors.gold : TableColors.available,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel money formatting: whole riyals stay clean (`120`), anything else
/// keeps two decimals (`120.50`). No currency symbol — callers add SAR.
String formatMoney(double value) =>
    value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

/// `HH:mm`, or an em dash when the timestamp is missing.
String floorClock(DateTime? value) =>
    value == null ? '—' : DateFormat('HH:mm').format(value);

/// Sales · open bills · occupancy · reservations. Every figure comes from the
/// server snapshot; none is recomputed from another tile.
class TodayStrip extends StatelessWidget {
  const TodayStrip({
    super.key,
    required this.kpi,
    this.onSales,
    this.onBills,
    this.onOccupancy,
    this.onReservations,
  });

  final PanelFloorKpi kpi;
  final VoidCallback? onSales;
  final VoidCallback? onBills;
  final VoidCallback? onOccupancy;
  final VoidCallback? onReservations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112.h,
      child: ListView(
        key: const Key('today_strip'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _TodayTile(
            key: const Key('tile_sales'),
            label: 'today_sales'.tr(),
            value: '${formatMoney(kpi.salesToday)} SAR',
            sub: '${kpi.ordersToday} ${'orders'.tr().toLowerCase()}',
            icon: Iconsax.trend_up,
            dark: true,
            onTap: onSales,
          ),
          SizedBox(width: 9.w),
          _TodayTile(
            key: const Key('tile_bills'),
            label: 'open_bills'.tr(),
            value: '${kpi.openBills}',
            sub: '${formatMoney(kpi.openBillsTotal)} SAR',
            icon: Iconsax.receipt_1,
            onTap: onBills,
          ),
          SizedBox(width: 9.w),
          _TodayTile(
            key: const Key('tile_occupancy'),
            label: 'occupancy'.tr(),
            value: '${kpi.occupiedTables}/${kpi.totalTables}',
            sub: '${kpi.occupancyPct}%',
            icon: Iconsax.people,
            progress: kpi.totalTables == 0
                ? 0
                : kpi.occupiedTables / kpi.totalTables,
            onTap: onOccupancy,
          ),
          SizedBox(width: 9.w),
          _TodayTile(
            key: const Key('tile_reservations'),
            label: 'reservations_today'.tr(),
            value: '${kpi.reservationsToday}',
            sub: kpi.nextReservationAt == null
                ? 'today'.tr()
                : '${'next_at'.tr()} ${floorClock(kpi.nextReservationAt)}',
            icon: Iconsax.calendar_1,
            onTap: onReservations,
          ),
          SizedBox(width: 16.w),
        ],
      ),
    );
  }
}

/// Bill / card machine / waiter asks, oldest first. One tap clears it, one
/// tap on the card opens the table.
class AttentionRail extends StatelessWidget {
  const AttentionRail({
    super.key,
    required this.tables,
    required this.onOpen,
    required this.onHandle,
    this.busyTableId,
  });

  final List<PanelPhysicalTable> tables;
  final void Function(PanelPhysicalTable) onOpen;
  final void Function(PanelPhysicalTable, PanelServiceRequestSummary) onHandle;
  final String? busyTableId;

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RailHeader(
          key: const Key('attention_header'),
          icon: Iconsax.notification_bing,
          color: TableColors.attention,
          title: 'attention'.tr(),
          count: tables.length,
        ),
        SizedBox(
          height: 74.h,
          child: ListView.separated(
            key: const Key('attention_rail'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: tables.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final table = tables[index];
              final request = table.pendingRequests.first;
              final age = _ageMinutes(request.createdAt);
              final busy = busyTableId == table.id;
              return _AttentionCard(
                table: table,
                request: request,
                age: age,
                busy: busy,
                onOpen: () => onOpen(table),
                onHandle: () => onHandle(table, request),
              );
            },
          ),
        ),
      ],
    );
  }
}

int? _ageMinutes(String iso) {
  final at = DateTime.tryParse(iso);
  if (at == null) return null;
  final minutes = DateTime.now().difference(at.toLocal()).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.table,
    required this.request,
    required this.age,
    required this.busy,
    required this.onOpen,
    required this.onHandle,
  });

  final PanelPhysicalTable table;
  final PanelServiceRequestSummary request;
  final int? age;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onHandle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        key: Key('attention_${table.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 236.w,
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: TableColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: TableColors.attention.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11.r),
                ),
                child: Icon(
                  requestIcon(request.type),
                  size: 16.sp,
                  color: TableColors.attention,
                ),
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${requestLabel(request.type)} · ${table.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: TableColors.ink,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        if (request.guestLabel.isNotEmpty) request.guestLabel,
                        if (age != null) 'request_age'.tr(args: ['$age']),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              IconButton(
                key: Key('handle_${request.id}'),
                tooltip: 'mark_handled'.tr(),
                onPressed: busy ? null : onHandle,
                visualDensity: VisualDensity.compact,
                icon: busy
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Iconsax.tick_circle,
                        size: 19.sp,
                        color: TableColors.available,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    this.count,
  });

  final IconData icon;
  final String title;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
      child: Row(
        children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: TableColors.ink,
            ),
          ),
          if (count != null) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's bookings: time, guest, party, table, and the two actions staff
/// actually need at the door.
class ReservationsRail extends StatelessWidget {
  const ReservationsRail({
    super.key,
    required this.reservations,
    required this.tableLabel,
    required this.onOpen,
    this.onSeat,
    this.onNoShow,
    this.onCall,
  });

  final List<PanelTableReservation> reservations;
  final String Function(PanelTableReservation) tableLabel;
  final void Function(PanelTableReservation) onOpen;
  final void Function(PanelTableReservation)? onSeat;
  final void Function(PanelTableReservation)? onNoShow;
  final void Function(PanelTableReservation)? onCall;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RailHeader(
          key: const Key('reservations_header'),
          icon: Iconsax.calendar_tick,
          color: TableColors.reserved,
          title: 'reservations_rail'.tr(),
          count: reservations.length,
        ),
        SizedBox(
          height: 96.h,
          child: ListView.separated(
            key: const Key('reservations_rail'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: reservations.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              return _ReservationCard(
                reservation: reservation,
                tableLabel: tableLabel(reservation),
                onOpen: () => onOpen(reservation),
                onSeat: onSeat == null ? null : () => onSeat!(reservation),
                onNoShow: onNoShow == null
                    ? null
                    : () => onNoShow!(reservation),
                onCall: onCall == null ? null : () => onCall!(reservation),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.tableLabel,
    required this.onOpen,
    this.onSeat,
    this.onNoShow,
    this.onCall,
  });

  final PanelTableReservation reservation;
  final String tableLabel;
  final VoidCallback onOpen;
  final VoidCallback? onSeat;
  final VoidCallback? onNoShow;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        key: Key('reservation_${reservation.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 248.w,
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: TableColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    floorClock(reservation.startAt),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: TableColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      reservation.status == 'seated'
                          ? 'reservation_seated'.tr()
                          : 'reservation_expected'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ),
                  if (tableLabel.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: TableColors.reserved.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tableLabel,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: TableColors.reserved,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                [
                  reservation.customerName,
                  'party_of'.tr(args: ['${reservation.guestsCount}']),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: TableColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (onSeat != null && reservation.isExpected)
                    _MiniAction(
                      key: Key('seat_${reservation.id}'),
                      label: 'seat_now'.tr(),
                      color: TableColors.available,
                      onTap: onSeat!,
                    ),
                  if (onNoShow != null && reservation.isExpected) ...[
                    SizedBox(width: 6.w),
                    _MiniAction(
                      key: Key('noshow_${reservation.id}'),
                      label: 'no_show'.tr(),
                      color: TableColors.inkSoft,
                      onTap: onNoShow!,
                    ),
                  ],
                  if (onCall != null &&
                      reservation.customerPhone.isNotEmpty) ...[
                    SizedBox(width: 6.w),
                    IconButton(
                      key: Key('call_${reservation.id}'),
                      tooltip: 'call_guest'.tr(),
                      onPressed: onCall,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Iconsax.call,
                        size: 15.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Search + status + zone filters. Two compact rows: statuses carry counts,
/// zones are quiet chips.
class FloorFilterBar extends StatelessWidget {
  const FloorFilterBar({
    super.key,
    required this.query,
    required this.filter,
    required this.zone,
    required this.counts,
    required this.zones,
    required this.searchController,
    required this.onQuery,
    required this.onFilter,
    required this.onZone,
  });

  final String query;
  final FloorFilter filter;
  final String? zone;
  final Map<FloorFilter, int> counts;
  final List<({String zone, int count})> zones;
  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final ValueChanged<FloorFilter> onFilter;
  final ValueChanged<String?> onZone;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('floor_filters'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
          child: TextField(
            key: const Key('table_search'),
            controller: searchController,
            onChanged: onQuery,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 13.sp, color: TableColors.ink),
            decoration: InputDecoration(
              hintText: 'search_tables'.tr(),
              hintStyle: TextStyle(fontSize: 12.sp, color: TableColors.inkSoft),
              prefixIcon: Icon(
                Iconsax.search_normal_1,
                size: 17.sp,
                color: TableColors.inkSoft,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('clear_search'),
                      onPressed: () {
                        searchController.clear();
                        onQuery('');
                      },
                      icon: Icon(
                        Iconsax.close_circle,
                        size: 16.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: TableColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: TableColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(
                  color: TableColors.gold,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 30.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            children: [
              for (final f in FloorFilter.values) ...[
                _FilterChip(
                  key: Key('filter_${f.name}'),
                  label: switch (f) {
                    FloorFilter.all => 'filter_all'.tr(),
                    FloorFilter.occupied => 'filter_occupied'.tr(),
                    FloorFilter.available => 'filter_available'.tr(),
                    FloorFilter.reserved => 'filter_reserved'.tr(),
                    FloorFilter.attention => 'filter_attention'.tr(),
                  },
                  count: counts[f] ?? 0,
                  selected: filter == f,
                  alert: f == FloorFilter.attention,
                  onTap: () => onFilter(f),
                ),
                SizedBox(width: 6.w),
              ],
            ],
          ),
        ),
        if (zones.isNotEmpty) ...[
          SizedBox(height: 8.h),
          SizedBox(
            height: 28.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _ZoneChip(
                  key: const Key('zone_all'),
                  label: 'filter_all'.tr(),
                  selected: zone == null,
                  onTap: () => onZone(null),
                ),
                SizedBox(width: 6.w),
                for (final z in zones) ...[
                  _ZoneChip(
                    key: Key('zone_${z.zone}'),
                    label: '${z.zone} · ${z.count}',
                    selected: zone == z.zone,
                    onTap: () => onZone(z.zone),
                  ),
                  SizedBox(width: 6.w),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.alert = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert && count > 0 ? TableColors.attention : TableColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 11.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? TableColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? TableColors.ink : TableColors.line,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 5.w),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.6)
                      : TableColors.inkSoft,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TableColors.gold.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? TableColors.gold.withValues(alpha: 0.5)
                : TableColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? TableColors.goldDark : TableColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// The spatial floor. Positions are fractions of the canvas, so the same
/// layout works on a phone and a tablet. Coordinates never mirror in RTL: a
/// mirrored floor map is a lie.
class FloorCanvas extends StatelessWidget {
  const FloorCanvas({
    super.key,
    required this.tables,
    required this.arranging,
    required this.selectedIds,
    required this.onTap,
    required this.onSelect,
    required this.onMove,
    this.onSaveAsLayout,
  });

  final List<PanelPhysicalTable> tables;
  final bool arranging;
  final Set<String> selectedIds;
  final void Function(PanelPhysicalTable) onTap;
  final void Function(PanelPhysicalTable) onSelect;
  final void Function(String id, double x, double y) onMove;
  final VoidCallback? onSaveAsLayout;

  @override
  Widget build(BuildContext context) {
    final hasLayout = tables.any((t) => t.positioned);
    return Container(
      key: const Key('floor_canvas'),
      height: 380.h,
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      decoration: BoxDecoration(
        color: TableColors.canvas,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: TableColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final positions = _positions(tables, width, height);
          return InteractiveViewer(
            panEnabled: !arranging,
            scaleEnabled: !arranging,
            minScale: 0.8,
            maxScale: 2.4,
            boundaryMargin: const EdgeInsets.all(60),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotGridPainter(
                        color: TableColors.line.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (hasLayout) ..._zoneBackdrops(tables, width, height),
                  for (final entry in positions.entries)
                    _FloorTile(
                      key: Key('floor_${entry.key.id}'),
                      table: entry.key,
                      size: entry.value,
                      arranging: arranging,
                      selected: selectedIds.contains(entry.key.id),
                      width: width,
                      height: height,
                      onTap: () =>
                          arranging ? onSelect(entry.key) : onTap(entry.key),
                      onMove: (dx, dy) {
                        final size = entry.value;
                        final x = (entry.value.left + dx) / width;
                        final y = (entry.value.top + dy) / height;
                        onMove(
                          entry.key.id,
                          x.clamp(0.0, 1.0 - size.width / width),
                          y.clamp(0.0, 1.0 - size.height / height),
                        );
                      },
                    ),
                  if (!hasLayout && onSaveAsLayout != null)
                    Positioned(
                      left: 12.w,
                      bottom: 12.h,
                      child: _AutoGridNote(onSave: onSaveAsLayout!),
                    ),
                  if (arranging)
                    Positioned(
                      right: 10.w,
                      top: 10.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: TableColors.ink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'drag_hint'.tr(),
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Positioned tables keep their saved fractions; unpositioned ones fall
  /// into an auto-grid so the canvas is never an empty tray.
  Map<PanelPhysicalTable, Rect> _positions(
    List<PanelPhysicalTable> rows,
    double width,
    double height,
  ) {
    final positioned = rows.where((t) => t.positioned).toList();
    final loose = rows.where((t) => !t.positioned).toList();
    final result = <PanelPhysicalTable, Rect>{};
    for (final table in positioned) {
      final size = _tileSize(table.seats);
      result[table] = Rect.fromLTWH(
        table.x! * width - size.width / 2,
        table.y! * height - size.height / 2,
        size.width,
        size.height,
      );
    }
    if (loose.isEmpty) return result;

    final columns = loose.length <= 4 ? 2 : (loose.length <= 9 ? 3 : 4);
    const gap = 10.0;
    final tileW = math.min(82.0, (width - 32 - gap * (columns - 1)) / columns);
    final tileH = 62.0;
    final rowsCount = (loose.length / columns).ceil();
    final startY = math.max(44.0, (height - rowsCount * (tileH + gap)) / 2);
    for (var i = 0; i < loose.length; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      result[loose[i]] = Rect.fromLTWH(
        16 + col * (tileW + gap),
        startY + row * (tileH + gap),
        tileW,
        tileH,
      );
    }
    return result;
  }

  Size _tileSize(int seats) {
    if (seats <= 2) return const Size(68, 58);
    if (seats <= 4) return const Size(76, 62);
    if (seats <= 6) return const Size(84, 66);
    return const Size(92, 70);
  }

  List<Widget> _zoneBackdrops(
    List<PanelPhysicalTable> rows,
    double width,
    double height,
  ) {
    final byZone = <String, List<PanelPhysicalTable>>{};
    for (final table in rows) {
      final zone = table.zone;
      if (zone == null || zone.isEmpty || !table.positioned) continue;
      byZone.putIfAbsent(zone, () => []).add(table);
    }
    final widgets = <Widget>[];
    byZone.forEach((zone, members) {
      var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
      for (final table in members) {
        minX = math.min(minX, table.x!);
        maxX = math.max(maxX, table.x!);
        minY = math.min(minY, table.y!);
        maxY = math.max(maxY, table.y!);
      }
      final left = (minX * width - 34).clamp(4.0, width - 40);
      final top = (minY * height - 30).clamp(4.0, height - 40);
      final right = (maxX * width + 34).clamp(left + 60, width - 4);
      final bottom = (maxY * height + 34).clamp(top + 50, height - 4);
      final color = _zoneColor(zone);
      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: right - left,
          height: bottom - top,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: color.withValues(alpha: 0.16)),
              ),
              child: Padding(
                padding: EdgeInsets.all(6.w),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Text(
                    zone,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
    return widgets;
  }

  Color _zoneColor(String zone) {
    var hash = 0;
    for (final unit in zone.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.45, 0.42).toColor();
  }
}

class _AutoGridNote extends StatelessWidget {
  const _AutoGridNote({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 6.h, 6.w, 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TableColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.grid_5, size: 12.sp, color: TableColors.inkSoft),
          SizedBox(width: 5.w),
          Text(
            'auto_grid_note'.tr(),
            style: TextStyle(fontSize: 9.sp, color: TableColors.inkSoft),
          ),
          SizedBox(width: 4.w),
          TextButton(
            key: const Key('save_as_layout'),
            onPressed: onSave,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 26),
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'save_as_layout'.tr(),
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: TableColors.goldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorTile extends StatelessWidget {
  const _FloorTile({
    super.key,
    required this.table,
    required this.size,
    required this.arranging,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
    required this.onMove,
  });

  final PanelPhysicalTable table;
  final Rect size;
  final bool arranging;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onMove;

  @override
  Widget build(BuildContext context) {
    final color = TableColors.of(table.floorStatus);
    final inactive = table.floorStatus == 'inactive';
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: inactive
            ? Colors.white.withValues(alpha: 0.65)
            : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: selected ? TableColors.ink : color.withValues(alpha: 0.42),
          width: selected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 5.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    table.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: inactive ? TableColors.inactive : TableColors.ink,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${table.seats} ${'seats'.tr().toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.sp,
                      color: TableColors.inkSoft,
                      height: 1.1,
                    ),
                  ),
                  if (table.billTotal > 0) ...[
                    SizedBox(height: 3.h),
                    Text(
                      formatMoney(table.billTotal),
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (table.hasAttention)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: TableColors.attention,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
              ),
            ),
          if (table.guestCount > 0)
            Positioned(
              bottom: 3,
              right: 4,
              child: Text(
                '·${table.guestCount}',
                style: TextStyle(
                  fontSize: 8.sp,
                  color: TableColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    return Positioned(
      left: size.left,
      top: size.top,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: arranging
            ? (details) => onMove(details.delta.dx, details.delta.dy)
            : null,
        child: tile,
      ),
    );
  }
}

/// One dense operational row: who is at the table, what is on it, what is
/// owed, and the one thing that needs doing.
class TableListRow extends StatelessWidget {
  const TableListRow({
    super.key,
    required this.table,
    required this.onTap,
    this.onQr,
  });

  final PanelPhysicalTable table;
  final VoidCallback onTap;
  final VoidCallback? onQr;

  @override
  Widget build(BuildContext context) {
    final status = table.floorStatus;
    final color = TableColors.of(status);
    final session = table.openSession;
    final reservation = table.reservation;

    final String title;
    final String subtitle;
    if (status == 'occupied') {
      title = session?.code.isNotEmpty == true
          ? '${'session_label'.tr()} ${session!.code}'
          : 'status_occupied'.tr();
      subtitle = [
        '${table.guestCount} ${'guests'.tr().toLowerCase()}',
        '${table.openItemCount} ${'orders'.tr().toLowerCase()}',
      ].join(' · ');
    } else if (status == 'reserved' && reservation != null) {
      title = reservation.customerName;
      subtitle = [
        floorClock(reservation.startAt),
        'party_of'.tr(args: ['${reservation.guestsCount}']),
      ].join(' · ');
    } else if (status == 'inactive') {
      title = 'status_inactive'.tr();
      subtitle = table.typeLabel;
    } else {
      title = 'status_available'.tr();
      subtitle = [
        if (table.typeLabel.isNotEmpty) table.typeLabel,
        '${table.seats} ${'seats'.tr().toLowerCase()}',
      ].join(' · ');
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          key: Key('table_row_${table.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: TableColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        table.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: TableColors.ink,
                        ),
                      ),
                      Text(
                        '${table.seats}',
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: TableColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: TableColors.ink,
                              ),
                            ),
                          ),
                          TableStatusPill(status: status, compact: true),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: TableColors.inkSoft,
                              ),
                            ),
                          ),
                          if (table.billTotal > 0)
                            Text(
                              '${formatMoney(table.billTotal)} SAR',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                                color: TableColors.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (table.hasAttention) ...[
                        SizedBox(height: 5.h),
                        Row(
                          children: [
                            Icon(
                              Iconsax.notification_bing,
                              size: 11.sp,
                              color: TableColors.attention,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              table.pendingRequests
                                  .map((r) => requestLabel(r.type))
                                  .join(' · '),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: TableColors.attention,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onQr != null) ...[
                  SizedBox(width: 2.w),
                  IconButton(
                    key: Key('qr_row_${table.id}'),
                    tooltip: 'table_qr'.tr(),
                    onPressed: onQr,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Iconsax.scan_barcode,
                      size: 17.sp,
                      color: TableColors.inkSoft,
                    ),
                  ),
                ],
                Icon(
                  Iconsax.arrow_left_2,
                  size: 15.sp,
                  color: TableColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Updated 14:32" plus the honest stale warning when polling fails.
class UpdatedFooter extends StatelessWidget {
  const UpdatedFooter({super.key, required this.at, required this.stale});

  final DateTime? at;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    if (at == null) return const SizedBox.shrink();
    final time = DateFormat('HH:mm').format(at!);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
      child: Container(
        key: const Key('updated_footer'),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: stale
              ? TableColors.attention.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              stale ? Iconsax.warning_2 : Iconsax.refresh,
              size: 12.sp,
              color: stale ? TableColors.attention : TableColors.inkSoft,
            ),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(
                stale ? 'stale_floor'.tr() : 'updated_ago'.tr(args: [time]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5.sp,
                  color: stale ? TableColors.attention : TableColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 22.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
