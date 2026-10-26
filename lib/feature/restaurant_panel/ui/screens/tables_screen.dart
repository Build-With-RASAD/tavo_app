// lib/feature/restaurant_panel/ui/screens/tables_screen.dart
//
// The floor control room. One aggregate read (`GET /floor`) drives the whole
// screen: today's money, the guest-ask rail, today's arrivals, the spatial
// floor and the dense list. Staff never open a second screen to answer "who
// is where, what do they owe, and who is waiting".
//
//   • View mode: floor canvas (default) or dense list.
//   • Arrange mode (manageable roles): drag tiles, snap to 0.05, save layout.
//   • Bulk mode: select tables, set a shared zone, activate/deactivate.
//
// Destructive actions (delete, settle, rotate QR) always confirm, and the
// sheet for one table carries its QR, party, tickets, bill and booking.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_tables/data/model/floor_models.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/logic/tables_panel_cubit.dart';
import 'package:tavo/feature/panel_tables/ui/screens/table_qr_batch_screen.dart';
import 'package:tavo/feature/panel_tables/ui/screens/table_sheet.dart';
import 'package:tavo/feature/panel_tables/ui/widgets/tables_widgets.dart';

enum _TablesView { floor, list }

/// Staff panel floor plan — the live control room.
class TablesScreen extends StatefulWidget {
  const TablesScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    this.onOpenOrders,
    this.autoRefresh = true,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  /// Opens the Orders tab. The shell wires it; `null` when the screen runs
  /// standalone (the sheet then hides "open orders").
  final VoidCallback? onOpenOrders;

  /// Tests disable the 25 s poll so no timer outlives the widget tree.
  final bool autoRefresh;

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  final TextEditingController _search = TextEditingController();

  _TablesView _view = _TablesView.floor;
  bool _snap = true;
  bool _wasSaving = false;

  bool get _canManage =>
      widget.venue.canManage ||
      widget.venue.permissions.contains('manage_tables');

  /// Seating a booking needs `manage_reservations`; read-only staff still see
  /// the booking, they just cannot move it.
  bool get _canSeat =>
      _canManage || widget.venue.permissions.contains('manage_reservations');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? TableColors.attention : TableColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.all(16.w),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TablesPanelCubit(
        GetIt.instance<TablesPanelRepo>(),
        restaurantId: widget.restaurantId,
        autoRefresh: widget.autoRefresh,
      )..load(),
      child: BlocConsumer<TablesPanelCubit, TablesPanelState>(
        listener: (context, state) {
          if (state is! TablesPanelLoaded) return;
          if (state.actionError != null) {
            _toast(state.actionError!, error: true);
            context.read<TablesPanelCubit>().clearActionError();
          } else if (_wasSaving && !state.saving) {
            _toast('arranged_saved'.tr());
          }
          _wasSaving = state.saving;
        },
        builder: (context, state) {
          final cubit = context.read<TablesPanelCubit>();
          return Scaffold(
            backgroundColor: TableColors.canvas,
            body: SafeArea(
              child: switch (state) {
                TablesPanelError() => ErrorStateView(
                  message: state.message,
                  onRetry: cubit.load,
                ),
                TablesPanelLoaded() => _body(context, cubit, state),
                _ => const ListSkeleton(),
              },
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    final attention = state.attentionTables;
    final reservations = state.upcomingReservations;

    if (state.tables.isEmpty && state.types.isEmpty) {
      return Column(
        children: [
          _header(context, cubit, state),
          Expanded(
            child: EmptyStateView(
              icon: Iconsax.grid_4,
              title: 'empty_tables_title'.tr(),
              message: 'empty_tables_message'.tr(),
              onRetry: cubit.load,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: TableColors.gold,
      onRefresh: () => cubit.refresh(silent: true),
      child: SingleChildScrollView(
        key: const Key('tables_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, cubit, state),
            SizedBox(height: 14.h),
            TodayStrip(
              kpi: state.kpi,
              onSales: () => _openList(context, cubit, FloorFilter.occupied),
              onBills: () => _openList(context, cubit, FloorFilter.occupied),
              onOccupancy: () =>
                  _openList(context, cubit, FloorFilter.occupied),
              onReservations: () =>
                  _openList(context, cubit, FloorFilter.reserved),
            ),
            if (attention.isNotEmpty)
              AttentionRail(
                tables: attention,
                busyTableId: state.actionId,
                onOpen: (table) => _openSheet(context, cubit, state, table),
                onHandle: (table, request) async {
                  final ok = await cubit.handleRequest(table.id, request.id);
                  if (ok) _toast('status_handled'.tr());
                },
              ),
            if (reservations.isNotEmpty)
              ReservationsRail(
                reservations: reservations,
                tableLabel: state.tableLabelFor,
                onOpen: (reservation) =>
                    _openReservation(context, state, reservation),
                onSeat: _canSeat
                    ? (reservation) async {
                        final ok = await cubit.seatReservation(reservation.id);
                        if (ok) _toast('reservation_seated'.tr());
                      }
                    : null,
                onNoShow: _canSeat
                    ? (reservation) async {
                        final ok = await cubit.markReservationNoShow(
                          reservation.id,
                        );
                        if (ok) _toast('no_show'.tr());
                      }
                    : null,
              ),
            _viewBar(context, cubit, state),
            if (state.tables.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 48.h, 24.w, 24.h),
                child: Column(
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(
                        color: TableColors.gold.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Iconsax.grid_1,
                          size: 28.sp, color: TableColors.goldDark),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'empty_tables_title'.tr(),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: TableColors.ink,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'empty_tables_message'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                    if (_canManage) ...[
                      SizedBox(height: 14.h),
                      TavoButton.primary(
                        key: const Key('empty_add_table'),
                        label: 'add_table'.tr(),
                        size: TavoButtonSize.compact,
                        leading: const Icon(Iconsax.add, size: 16),
                        onPressed: () => _showTableForm(context, cubit),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              FloorFilterBar(
                query: state.query,
                filter: state.filter,
                zone: state.zone,
                counts: _filterCounts(state),
                zones: state.zones,
                searchController: _search,
                onQuery: cubit.setQuery,
                onFilter: cubit.setFilter,
                onZone: cubit.setZone,
              ),
              SizedBox(height: 6.h),
              if (state.visibleTables.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: EmptyStateView(
                    icon: Iconsax.search_normal_1,
                    title: 'no_results'.tr(),
                    onRetry: cubit.clearFilters,
                  ),
                )
              else if (_view == _TablesView.floor)
                FloorCanvas(
                  tables: state.visibleTables,
                  arranging: state.arranging,
                  selectedIds: state.selected,
                  onTap: (table) {
                    if (state.selecting) {
                      cubit.toggleSelected(table.id);
                    } else {
                      _openSheet(context, cubit, state, table);
                    }
                  },
                  onSelect: (table) => cubit.toggleSelected(table.id),
                  onMove: (id, x, y) => cubit.moveTable(id, x, y, snap: _snap),
                  onSaveAsLayout: _canManage
                      ? () => _saveAutoGrid(cubit, state)
                      : null,
                )
              else
                for (final table in state.visibleTables)
                  Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: TableListRow(
                      table: table,
                      onTap: () {
                        if (state.selecting) {
                          cubit.toggleSelected(table.id);
                        } else {
                          _openSheet(context, cubit, state, table);
                        }
                      },
                      onQr: () => _openSheet(context, cubit, state, table),
                    ),
                  ),
              if (state.arranging) _arrangeBar(context, cubit, state),
              if (state.selecting) _bulkBar(context, cubit, state),
              UpdatedFooter(at: state.generatedAt, stale: state.stale),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'floor_live'.tr(),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: TableColors.ink,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(width: 7.w),
                        if (state.stale)
                          Icon(
                            Iconsax.warning_2,
                            size: 14.sp,
                            color: TableColors.attention,
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        DateFormat('EEE d MMM').format(DateTime.now()),
                        if (state.kpi.seatedNow > 0)
                          '${state.kpi.seatedNow} ${'guests'.tr().toLowerCase()}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.tables.isNotEmpty) ...[
                _HeaderAction(
                  key: const Key('batch_qr'),
                  icon: Iconsax.printer,
                  tooltip: 'print_qr'.tr(),
                  onTap: () => _openBatch(context, cubit, state),
                ),
                SizedBox(width: 4.w),
              ],
              if (_canManage && state.tables.isNotEmpty) ...[
                _HeaderAction(
                  key: const Key('select_tables'),
                  icon: state.selecting ? Iconsax.close_circle : Iconsax.grid_2,
                  tooltip: state.selecting
                      ? 'cancel'.tr()
                      : 'select_tables'.tr(),
                  active: state.selecting,
                  onTap: () => cubit.setSelecting(!state.selecting),
                ),
                SizedBox(width: 4.w),
              ],
              if (_canManage)
                _HeaderAction(
                  key: const Key('add_table'),
                  icon: Iconsax.add,
                  tooltip: 'add_table'.tr(),
                  onTap: () => _showTableForm(context, cubit),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Floor/List switch plus the arrange entry point for managers.
  Widget _viewBar(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11.r),
              border: Border.all(color: TableColors.line),
            ),
            child: Row(
              children: [
                _ViewTab(
                  key: const Key('view_floor'),
                  icon: Iconsax.element_3,
                  label: 'view_floor'.tr(),
                  selected: _view == _TablesView.floor,
                  onTap: () => setState(() => _view = _TablesView.floor),
                ),
                _ViewTab(
                  key: const Key('view_list'),
                  icon: Iconsax.menu_board,
                  label: 'view_list'.tr(),
                  selected: _view == _TablesView.list,
                  onTap: () => setState(() => _view = _TablesView.list),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_canManage && !state.selecting)
            TavoButton.ghost(
              key: const Key('arrange_mode'),
              label: state.arranging ? 'done'.tr() : 'arrange'.tr(),
              size: TavoButtonSize.compact,
              leading: Icon(
                state.arranging ? Iconsax.close_circle : Iconsax.edit_2,
                size: 15,
              ),
              onPressed: () =>
                  state.arranging ? cubit.exitArrange() : cubit.enterArrange(),
            ),
        ],
      ),
    );
  }

  // ── Arrange / bulk ───────────────────────────────────────────────────────

  Widget _arrangeBar(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    return Container(
      key: const Key('arrange_bar'),
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: TableColors.ink,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Iconsax.grid_5, size: 14.sp, color: Colors.white70),
          SizedBox(width: 6.w),
          Text(
            'drag_hint'.tr(),
            style: TextStyle(fontSize: 10.sp, color: Colors.white70),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'snap_grid'.tr(),
                style: TextStyle(fontSize: 10.sp, color: Colors.white70),
              ),
              SizedBox(width: 4.w),
              SizedBox(
                height: 22.h,
                child: Switch(
                  key: const Key('snap_switch'),
                  value: _snap,
                  onChanged: (value) => setState(() => _snap = value),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          SizedBox(width: 6.w),
          SizedBox(
            height: 32.h,
            child: FilledButton(
              key: const Key('save_floor'),
              onPressed: state.saving
                  ? null
                  : () async {
                      final ok = await cubit.saveFloorPlan();
                      if (ok) cubit.exitArrange();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: TableColors.gold,
                foregroundColor: TableColors.goldDark,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9.r),
                ),
              ),
              child: state.saving
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TableColors.goldDark,
                      ),
                    )
                  : Text(
                      'save_layout'.tr(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulkBar(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    final count = state.selected.length;
    return Container(
      key: const Key('bulk_bar'),
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: TableColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: TableColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: TableColors.goldDark,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            'select_tables'.tr(),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: TableColors.ink,
            ),
          ),
          const Spacer(),
          TavoButton.ghost(
            key: const Key('bulk_zone'),
            label: 'zone'.tr(),
            size: TavoButtonSize.compact,
            onPressed: count == 0
                ? null
                : () => _showBulkZone(context, cubit, state),
          ),
          SizedBox(width: 4.w),
          TavoButton.ghost(
            key: const Key('bulk_inactive'),
            label: 'deactivate'.tr(),
            size: TavoButtonSize.compact,
            onPressed: count == 0
                ? null
                : () =>
                      cubit.bulkSetStatus(state.selected.toList(), 'inactive'),
          ),
          SizedBox(width: 4.w),
          TavoButton.ghost(
            key: const Key('bulk_available'),
            label: 'activate'.tr(),
            size: TavoButtonSize.compact,
            onPressed: count == 0
                ? null
                : () =>
                      cubit.bulkSetStatus(state.selected.toList(), 'available'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkZone(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) async {
    final controller = TextEditingController();
    final zone = await TavoSheet.show<String>(
      context,
      title: 'zone'.tr(),
      subtitle: 'zone_none'.tr(),
      maxHeightFactor: 0.42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('bulk_zone_field'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: 'zone_none'.tr()),
          ),
          SizedBox(height: TavoSpace.xl),
          Row(
            children: [
              Expanded(
                child: TavoButton.secondary(
                  label: 'cancel'.tr(),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: TavoSpace.md),
              Expanded(
                child: TavoButton.primary(
                  key: const Key('bulk_zone_save'),
                  label: 'save'.tr(),
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    controller.dispose();
    if (zone == null || zone.isEmpty) return;
    await cubit.bulkSetZone(state.selected.toList(), zone);
  }

  /// Persists the auto-grid as a real layout: three columns, centred rows.
  Future<bool> _saveAutoGrid(
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) async {
    final rows = state.tables.length;
    final columns = rows <= 4 ? 2 : (rows <= 9 ? 3 : 4);
    final rowCount = (rows / columns).ceil();
    for (var i = 0; i < rows; i++) {
      final col = i % columns;
      final row = i ~/ columns;
      cubit.moveTable(
        state.tables[i].id,
        (col + 0.5) / columns,
        (row + 0.5) / rowCount,
      );
    }
    return cubit.saveFloorPlan();
  }

  // ── Openers ──────────────────────────────────────────────────────────────

  void _openList(
    BuildContext context,
    TablesPanelCubit cubit,
    FloorFilter filter,
  ) {
    setState(() => _view = _TablesView.list);
    cubit.setFilter(filter);
  }

  void _openSheet(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
    PanelPhysicalTable table,
  ) {
    showTableSheet(
      context,
      cubit: cubit,
      table: table,
      canManage: _canManage,
      canSeat: _canSeat,
      onOpenOrders: widget.onOpenOrders,
      onEdit: _canManage
          ? () async {
              Navigator.of(context).pop();
              await Future<void>.delayed(Duration.zero);
              if (!context.mounted) return;
              await _showTableForm(context, cubit, table: table);
            }
          : null,
      onDelete: _canManage
          ? () async {
              Navigator.of(context).pop();
              await Future<void>.delayed(Duration.zero);
              if (!context.mounted) return;
              await _confirmDelete(context, cubit, table);
            }
          : null,
    );
  }

  void _openReservation(
    BuildContext context,
    TablesPanelLoaded state,
    PanelTableReservation reservation,
  ) {
    if (reservation.tableIds.isEmpty) return;
    final table = state.tableById(reservation.tableIds.first);
    if (table == null) {
      _toast('reservation'.tr(), error: false);
      return;
    }
    _openSheet(context, context.read<TablesPanelCubit>(), state, table);
  }

  void _openBatch(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<TablesPanelCubit>.value(
          value: cubit,
          child: TableQrBatchScreen(tables: state.tables),
        ),
      ),
    );
  }

  // ── Forms ────────────────────────────────────────────────────────────────

  Future<void> _showTableForm(
    BuildContext context,
    TablesPanelCubit cubit, {
    PanelPhysicalTable? table,
  }) async {
    final state = cubit.state;
    if (state is! TablesPanelLoaded) return;
    if (table == null && state.types.isEmpty) {
      _toast('empty_tables_message'.tr(), error: true);
      return;
    }
    final code = TextEditingController(text: table?.code ?? '');
    final seats = TextEditingController(text: '${table?.seats ?? 2}');
    final zone = TextEditingController(text: table?.zone ?? '');
    var typeId =
        table?.tableTypeId ??
        (state.types.isNotEmpty ? state.types.first.id : '');

    final saved = await TavoSheet.show<bool>(
      context,
      title: table == null ? 'create_table'.tr() : 'edit_table'.tr(),
      subtitle: 'empty_tables_message'.tr(),
      maxHeightFactor: 0.86,
      child: StatefulBuilder(
        builder: (dialogContext, setLocal) => ListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          children: [
            if (table == null)
              DropdownButtonFormField<String>(
                key: const Key('table_type_field'),
                initialValue: typeId.isEmpty ? null : typeId,
                decoration: InputDecoration(labelText: 'table'.tr()),
                items: [
                  for (final type in state.types)
                    DropdownMenuItem(value: type.id, child: Text(type.label)),
                ],
                onChanged: (value) => setLocal(() => typeId = value ?? typeId),
              ),
            SizedBox(height: 8.h),
            TextField(
              key: const Key('table_code_field'),
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: 'table_code'.tr()),
            ),
            SizedBox(height: 8.h),
            TextField(
              key: const Key('table_seats_field'),
              controller: seats,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'seats'.tr()),
            ),
            SizedBox(height: 8.h),
            TextField(
              key: const Key('table_zone_field'),
              controller: zone,
              decoration: InputDecoration(
                labelText: 'zone'.tr(),
                hintText: 'zone_none'.tr(),
              ),
            ),
            SizedBox(height: TavoSpace.xl),
            Row(
              children: [
                Expanded(
                  child: TavoButton.secondary(
                    label: 'cancel'.tr(),
                    expand: true,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                SizedBox(width: TavoSpace.md),
                Expanded(
                  flex: 2,
                  child: TavoButton.primary(
                    key: const Key('save_table'),
                    label: 'save'.tr(),
                    expand: true,
                    onPressed: () {
                      if (code.text.trim().isEmpty || typeId.isEmpty) return;
                      Navigator.of(dialogContext).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final seatCount = int.tryParse(seats.text.trim()) ?? 2;
      final zoneText = zone.text.trim();
      final ok = table == null
          ? await cubit.createTable(
              tableTypeId: typeId,
              code: code.text.trim(),
              seats: seatCount,
              zone: zoneText.isEmpty ? null : zoneText,
            )
          : await cubit.updateTable(
              table.id,
              code: code.text.trim(),
              seats: seatCount,
              zone: zoneText.isEmpty ? null : zoneText,
              clearZone: zoneText.isEmpty,
            );
      if (ok) _toast(table == null ? 'create_table'.tr() : 'save'.tr());
    }

    code.dispose();
    seats.dispose();
    zone.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TablesPanelCubit cubit,
    PanelPhysicalTable table,
  ) async {
    final confirmed = await TavoSheet.show<bool>(
      context,
      title: 'delete_table_confirm'.tr(),
      subtitle: table.code,
      maxHeightFactor: 0.42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'delete_table_warning'.tr(),
            style: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
          SizedBox(height: TavoSpace.xl),
          Row(
            children: [
              Expanded(
                child: TavoButton.secondary(
                  label: 'cancel'.tr(),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: TavoSpace.md),
              Expanded(
                child: TavoButton.destructive(
                  key: const Key('confirm_delete_table'),
                  label: 'delete'.tr(),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await cubit.deleteTable(table.id);
    if (ok) _toast('delete_table'.tr());
  }

  Map<FloorFilter, int> _filterCounts(TablesPanelLoaded state) {
    final counts = <FloorFilter, int>{FloorFilter.all: state.tables.length};
    for (final table in state.tables) {
      if (table.floorStatus == 'occupied') {
        counts[FloorFilter.occupied] = (counts[FloorFilter.occupied] ?? 0) + 1;
      }
      if (table.floorStatus == 'available') {
        counts[FloorFilter.available] =
            (counts[FloorFilter.available] ?? 0) + 1;
      }
      if (table.floorStatus == 'reserved') {
        counts[FloorFilter.reserved] = (counts[FloorFilter.reserved] ?? 0) + 1;
      }
      if (table.hasAttention) {
        counts[FloorFilter.attention] =
            (counts[FloorFilter.attention] ?? 0) + 1;
      }
    }
    return counts;
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? TableColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(11.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11.r),
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11.r),
              border: Border.all(
                color: active ? TableColors.ink : TableColors.line,
              ),
            ),
            child: Icon(
              icon,
              size: 17.sp,
              color: active ? Colors.white : TableColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TableColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(9.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
          child: Row(
            children: [
              Icon(
                icon,
                size: 13.sp,
                color: selected ? Colors.white : TableColors.inkSoft,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : TableColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
