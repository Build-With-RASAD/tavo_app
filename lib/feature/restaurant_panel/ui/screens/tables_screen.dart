// lib/feature/restaurant_panel/ui/screens/tables_screen.dart
//
// Wave E3 (Task 28) — the tables redesign (Flutter half, Task 29-B).
//
// One floor canvas is the hero:
//   • View mode (default): the live floor — tables sized by seats, ringed by
//     their live state, a zone legend with tinted zone backdrops, tap opens
//     the detail sheet.
//   • Edit mode (manageable roles only): drag + optional snap-to-grid
//     (0.05), the unpositioned tray, add-table, multi-select bulk
//     zone/status and the save-layout button (`PUT /floor-plan`).
//
// The state colours pin the binding occupied rule exactly like T26's
// `floor_strip.dart` (inactive > occupied > reserved > available) so the
// dashboard strip and this floor can never drift apart. Occupancy itself is
// the server's `occupied` flag — the client never re-derives it.
//
// The editor is custom on purpose: `VisualTableMap`
// (`feature/booking/.../visual_table_map.dart`) is customer-booking shaped
// (`AvailableTable`, selection tap) and warping panel tables into it would
// couple the panel to the booking flow.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/logic/tables_panel_cubit.dart';

/// Canvas interaction modes (spec decision 1).
enum _CanvasMode { view, edit }

/// Staff panel floor plan: the live floor canvas, the zone legend, the
/// table detail sheet and — for manageable roles — the edit tools.
///
/// Builds its own [TablesPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Save/status failures surface as a SnackBar
/// while the editor keeps its positions (`TablesPanelLoaded.actionError`).
class TablesScreen extends StatefulWidget {
  const TablesScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    this.onOpenOrders,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  /// Opens the Orders tab (spec decision 5: an occupied table offers "view
  /// orders" instead of duplicating the dashboard's start-order flow). The
  /// shell wires it; `null` when the screen runs standalone.
  final VoidCallback? onOpenOrders;

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  /// Tracks the previous `saving` flag so the save-success toast fires only
  /// on the `saving: true → false` transition (the loaded state carries no
  /// saved flag of its own).
  bool _wasSaving = false;

  _CanvasMode _mode = _CanvasMode.view;
  bool _selecting = false;
  bool _snap = true;
  final Set<String> _selected = <String>{};

  /// Owner / manager / `full_access` / `manage_tables` may edit the floor.
  bool get _canManage =>
      widget.venue.role == 'owner' ||
      widget.venue.role == 'manager' ||
      widget.venue.permissions.contains('full_access') ||
      widget.venue.permissions.contains('manage_tables');

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
    final manageable = _canManage;
    return BlocProvider(
      create: (_) => TablesPanelCubit(
        GetIt.instance<TablesPanelRepo>(),
        restaurantId: widget.restaurantId,
      )..load(),
      child: BlocConsumer<TablesPanelCubit, TablesPanelState>(
        listener: (context, state) {
          if (state is! TablesPanelLoaded) return;
          if (_wasSaving && !state.saving && state.actionError == null) {
            _showSnack(context, 'layout_saved'.tr(), Colors.green.shade700);
          } else if (state.actionError != null) {
            // The backend's 409 blocker message is authoritative — show it
            // verbatim instead of a generic "could not delete" string.
            _showSnack(context, state.actionError!, const Color(0xFFC62828));
          }
          _wasSaving = state.saving;
        },
        builder: (context, state) {
          final cubit = context.read<TablesPanelCubit>();
          return Scaffold(
            body: SafeArea(
                child: _buildBody(context, cubit, state, manageable)),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TablesPanelCubit cubit,
    TablesPanelState state,
    bool manageable,
  ) {
    if (state is TablesPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.load,
          ),
          SizedBox(height: 8.h),
        ],
      );
    }
    if (state is TablesPanelLoaded) {
      if (state.types.isEmpty) {
        return EmptyStateView(
          icon: Icons.table_chart_outlined,
          title: 'empty_tables_title'.tr(),
          message: 'empty_tables_message'.tr(),
          onRetry: cubit.load,
        );
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(manageable),
            _buildTypeChips(cubit, state),
            if (manageable && _mode == _CanvasMode.edit)
              _buildEditToolbar(cubit, state),
            _buildLegend(state),
            SizedBox(height: 8.h),
            _buildCanvas(cubit, state, manageable),
            _buildTray(state),
            _buildBulkBar(cubit, state),
            if (manageable)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('save_floor'),
                    onPressed:
                        state.saving ? null : () => cubit.saveFloorPlan(),
                    child: state.saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('save_layout'.tr()),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // TablesPanelInitial / TablesPanelLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(bool manageable) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'floor_plan'.tr(),
              style: TextStyles.font18Black400Weight(context),
            ),
          ),
          if (manageable) ...[
            ChoiceChip(
              key: const Key('mode_view'),
              label: Text('tbl_view_mode'.tr()),
              selected: _mode == _CanvasMode.view,
              onSelected: (_) => _setMode(_CanvasMode.view),
            ),
            SizedBox(width: 8.w),
            ChoiceChip(
              key: const Key('mode_edit'),
              label: Text('tbl_edit_mode'.tr()),
              selected: _mode == _CanvasMode.edit,
              onSelected: (_) => _setMode(_CanvasMode.edit),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeChips(TablesPanelCubit cubit, TablesPanelLoaded state) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            for (final type in state.types)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  key: Key('type_${type.id}'),
                  label: Text(type.label),
                  selected: state.selectedTypeId == type.id,
                  onSelected: (_) => cubit.selectType(type.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Edit-mode tools: add a table, multi-select, snap-to-grid.
  Widget _buildEditToolbar(TablesPanelCubit cubit, TablesPanelLoaded state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('add_table'),
            icon: const Icon(Icons.add, size: 18),
            label: Text('tbl_add_table'.tr()),
            onPressed: () => _openAddForm(cubit, state),
          ),
          FilterChip(
            key: const Key('select_toggle'),
            label: Text('tbl_select'.tr()),
            selected: _selecting,
            onSelected: (v) => setState(() {
              _selecting = v;
              if (!v) _selected.clear();
            }),
          ),
          FilterChip(
            key: const Key('snap_toggle'),
            label: Text('tbl_snap'.tr()),
            selected: _snap,
            onSelected: (v) => setState(() => _snap = v),
          ),
        ],
      ),
    );
  }

  /// Distinct zones with their table counts (spec decision 4). Zones with no
  /// positioned table still show up here — only their backdrop is skipped.
  Widget _buildLegend(TablesPanelLoaded state) {
    final zones = _zoneCounts(state.tables);
    if (zones.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Wrap(
        key: const Key('zone_legend'),
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final entry in zones.entries)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: _zoneColor(entry.key).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10.r,
                    height: 10.r,
                    decoration: BoxDecoration(
                      color: _zoneColor(entry.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${entry.key} • ${entry.value}',
                    style: TextStyles.font12DarkGray400Weight(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The fractional canvas: positioned tables as rounded-rect cards sized by
  /// seats, dragged with `onPanUpdate` (fractions recomputed from the box
  /// size) and tinted zone backdrops behind them.
  Widget _buildCanvas(
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
    bool manageable,
  ) {
    final positioned = state.tables.where((t) => t.positioned).toList();
    return SizedBox(
      key: const Key('floor_editor'),
      height: 300.h,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: ColorsManager.grey100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: ColorsManager.grey200),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                for (final zone in _zoneCounts(state.tables).keys)
                  ..._zoneBackdrop(zone, state.tables, w, h),
                for (final table in positioned)
                  _buildTableCard(cubit, table, w, h, manageable),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One table card: rounded rect, sized by seats, ringed by its live state,
  /// dimmed when inactive and never hidden.
  Widget _buildTableCard(
    TablesPanelCubit cubit,
    PanelPhysicalTable table,
    double w,
    double h,
    bool manageable,
  ) {
    final size = _tableSize(table.seats);
    final color = _tableColor(table);
    final selected = _selected.contains(table.id);
    return Positioned(
      left: table.x! * w - size / 2,
      top: table.y! * h - size / 2,
      child: SizedBox(
        key: Key('table_${table.id}'),
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTableTap(cubit, table),
          onPanUpdate: manageable
              ? (details) => cubit.moveTable(
                    table.id,
                    (table.x! * w + details.delta.dx) / w,
                    (table.y! * h + details.delta.dy) / h,
                    snap: _mode == _CanvasMode.edit && _snap,
                  )
              : null,
          child: Opacity(
            key: Key('dim_${table.id}'),
            opacity: table.status == 'inactive' ? 0.55 : 1.0,
            child: Container(
              key: Key('table_card_${table.id}'),
              decoration: BoxDecoration(
                color: ColorsManager.white,
                borderRadius: BorderRadius.circular(size * 0.22),
                border: Border.all(color: color, width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Text(
                      table.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _seatDots(table.seats),
                    ),
                  ),
                  if (selected)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        key: Key('selected_${table.id}'),
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          color: ColorsManager.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 9,
                          color: ColorsManager.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A zone backdrop: the bounding box over that zone's positioned tables at
  /// 8% opacity plus its label. Zones without positioned tables are legend
  /// entries only.
  List<Widget> _zoneBackdrop(
    String zone,
    List<PanelPhysicalTable> tables,
    double w,
    double h,
  ) {
    final members = tables
        .where((t) => t.zone == zone && t.positioned)
        .toList();
    if (members.isEmpty) return const [];
    var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0;
    for (final t in members) {
      minX = t.x! < minX ? t.x! : minX;
      maxX = t.x! > maxX ? t.x! : maxX;
      minY = t.y! < minY ? t.y! : minY;
      maxY = t.y! > maxY ? t.y! : maxY;
    }
    const pad = 18.0;
    final color = _zoneColor(zone);
    return [
      Positioned(
        left: minX * w - pad,
        top: minY * h - pad,
        width: (maxX - minX) * w + pad * 2,
        height: (maxY - minY) * h + pad * 2,
        child: Container(
          key: Key('zone_backdrop_$zone'),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                zone,
                key: Key('zone_backdrop_label_$zone'),
                style: TextStyle(fontSize: 9, color: color),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Unpositioned (`position == null`) tables wait here as code cards.
  Widget _buildTray(TablesPanelLoaded state) {
    final tray = state.tables.where((t) => !t.positioned).toList();
    if (tray.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('floor_tray'),
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'unpositioned'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final table in tray)
                Chip(
                  label: Text(table.code),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Multi-select bulk bar (edit mode only): assign a zone, set a status.
  Widget _buildBulkBar(TablesPanelCubit cubit, TablesPanelLoaded state) {
    if (!_selecting || _selected.isEmpty) return const SizedBox.shrink();
    final ids = _selected.toList();
    final zones = _zoneCounts(state.tables).keys.toList();
    return Container(
      key: const Key('bulk_bar'),
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: ColorsManager.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tbl_selected_count'.tr(namedArgs: {'n': '${ids.length}'}),
            style: TextStyles.font12Black500Weight(context),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final zone in zones)
                ActionChip(
                  key: Key('bulk_zone_$zone'),
                  label: Text(zone),
                  onPressed: () => cubit.bulkSetZone(ids, zone),
                ),
              ActionChip(
                key: const Key('bulk_zone_new'),
                label: Text('tbl_new_zone'.tr()),
                onPressed: () => _askNewZone(cubit, ids),
              ),
              ActionChip(
                key: const Key('bulk_status_available'),
                label: Text('tbl_available'.tr()),
                onPressed: () => cubit.bulkSetStatus(ids, 'available'),
              ),
              ActionChip(
                key: const Key('bulk_status_inactive'),
                label: Text('tbl_inactive'.tr()),
                onPressed: () => cubit.bulkSetStatus(ids, 'inactive'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Creates a brand-new zone name and assigns it to the selection.
  Future<void> _askNewZone(TablesPanelCubit cubit, List<String> ids) async {
    final controller = TextEditingController();
    final zone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('tbl_new_zone'.tr()),
        content: TextField(
          key: const Key('bulk_zone_new_field'),
          controller: controller,
          decoration: InputDecoration(labelText: 'tbl_form_zone'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('tbl_delete_confirm_no'.tr()),
          ),
          TextButton(
            key: const Key('bulk_zone_new_save'),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('tbl_form_submit'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (zone == null || zone.isEmpty) return;
    await cubit.bulkSetZone(ids, zone);
  }

  void _setMode(_CanvasMode mode) {
    setState(() {
      _mode = mode;
      _selecting = false;
      _selected.clear();
    });
  }

  void _onTableTap(TablesPanelCubit cubit, PanelPhysicalTable table) {
    if (_selecting) {
      setState(() {
        if (!_selected.remove(table.id)) _selected.add(table.id);
      });
      return;
    }
    _openDetailSheet(cubit, table);
  }

  /// The table detail sheet (spec decision 5): code, seats, type, zone chip,
  /// status line, the occupied line + "view orders", and the edit / toggle /
  /// delete actions for manageable roles.
  Future<void> _openDetailSheet(
    TablesPanelCubit cubit,
    PanelPhysicalTable table,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TableDetailSheet(
        cubit: cubit,
        tableId: table.id,
        manageable: _canManage,
        typeLabel: _typeLabel(cubit.state, table.tableTypeId),
        onOpenOrders: widget.onOpenOrders,
      ),
    );
  }

  /// The add-table form (edit mode): code, seats and a zone for the selected
  /// table type.
  Future<void> _openAddForm(
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tbl_add_table'.tr(),
                style: TextStyles.font16Black500Weight(context),
              ),
              SizedBox(height: 12.h),
              _TableForm(
                initialCode: '',
                initialSeats: '',
                initialZone: '',
                zoneSuggestions: _zoneCounts(state.tables).keys.toList(),
                submitLabel: 'tbl_form_create'.tr(),
                closeOnSuccess: true,
                onSubmit: (code, seats, zone) => cubit.createTable(
                  code: code,
                  seats: seats,
                  zone: zone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Distinct zones → table count (insertion order keeps the legend stable).
  Map<String, int> _zoneCounts(List<PanelPhysicalTable> tables) {
    final counts = <String, int>{};
    for (final t in tables) {
      final zone = t.zone;
      if (zone == null || zone.isEmpty) continue;
      counts[zone] = (counts[zone] ?? 0) + 1;
    }
    return counts;
  }

  /// Hash-stable colour for a zone name (spec decision 4).
  Color _zoneColor(String zone) {
    var hash = 0;
    for (final unit in zone.codeUnits) {
      hash = (hash * 31 + unit) & 0x3fffffff;
    }
    return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.55, 0.45).toColor();
  }

  /// Table card size by seats (binding): 1–2 → 44, 3–4 → 52, 5–6 → 64,
  /// 7+ → 76 logical px.
  double _tableSize(int seats) {
    if (seats <= 2) return 44;
    if (seats <= 4) return 52;
    if (seats <= 6) return 64;
    return 76;
  }

  /// The live state colour — identical to T26's `floor_strip.dart`:
  /// inactive > occupied > reserved > available.
  Color _tableColor(PanelPhysicalTable table) {
    if (table.status == 'inactive') return Colors.grey;
    if (table.isOccupied) return Colors.orange;
    if (table.status == 'reserved') return Colors.red;
    return Colors.green;
  }

  Widget _seatDots(int seats) {
    final count = seats > 6 ? 6 : seats;
    if (count <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 1.5),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: ColorsManager.darkGray300,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  String? _typeLabel(TablesPanelState state, String tableTypeId) {
    if (state is! TablesPanelLoaded) return null;
    for (final type in state.types) {
      if (type.id == tableTypeId) return type.label;
    }
    return null;
  }
}

/// The detail bottom sheet: the table's identity, its live state and — for
/// manageable roles — the edit / status-toggle / delete actions.
class _TableDetailSheet extends StatefulWidget {
  const _TableDetailSheet({
    required this.cubit,
    required this.tableId,
    required this.manageable,
    required this.typeLabel,
    this.onOpenOrders,
  });

  final TablesPanelCubit cubit;
  final String tableId;
  final bool manageable;
  final String? typeLabel;
  final VoidCallback? onOpenOrders;

  @override
  State<_TableDetailSheet> createState() => _TableDetailSheetState();
}

class _TableDetailSheetState extends State<_TableDetailSheet> {
  bool _editing = false;

  PanelPhysicalTable? _tableOf(TablesPanelState state) {
    if (state is! TablesPanelLoaded) return null;
    for (final t in state.tables) {
      if (t.id == widget.tableId) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TablesPanelCubit, TablesPanelState>(
      bloc: widget.cubit,
      builder: (context, state) {
        final table = _tableOf(state);
        final acting =
            state is TablesPanelLoaded && state.actionId == widget.tableId;
        return Container(
          key: const Key('table_sheet'),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        table?.code ?? '',
                        key: const Key('sheet_title'),
                        style: TextStyles.font20Black500Weight(context),
                      ),
                    ),
                    if (acting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                SizedBox(height: 8.h),
                if (table == null)
                  Text('tbl_table_missing'.tr())
                else ...[
                  Text(
                    'tbl_seats_count'.tr(namedArgs: {'n': '${table.seats}'}),
                    style: TextStyles.font14Black400Weight(context),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'tbl_type_label'
                        .tr(namedArgs: {'label': widget.typeLabel ?? '-'}),
                    style: TextStyles.font14Black400Weight(context),
                  ),
                  SizedBox(height: 8.h),
                  if (table.zone != null && table.zone!.isNotEmpty)
                    Chip(
                      key: const Key('sheet_zone'),
                      label: Text(table.zone!),
                    ),
                  SizedBox(height: 4.h),
                  Text(
                    'tbl_status_line'
                        .tr(namedArgs: {'status': _statusLabel(table)}),
                    style: TextStyles.font14Black400Weight(context),
                  ),
                  if (table.isOccupied) ...[
                    SizedBox(height: 4.h),
                    Text(
                      'tbl_occupied_hint'.tr(),
                      key: const Key('sheet_occupied'),
                      style: TextStyles.font14Red500Weight(context),
                    ),
                    SizedBox(height: 8.h),
                    OutlinedButton.icon(
                      key: const Key('sheet_open_orders'),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text('tbl_open_orders'.tr()),
                      onPressed: _openOrders,
                    ),
                  ],
                ],
                SizedBox(height: 12.h),
                if (_editing && table != null)
                  _TableForm(
                    initialCode: table.code,
                    initialSeats: '${table.seats}',
                    initialZone: table.zone ?? '',
                    zoneSuggestions: const [],
                    submitLabel: 'tbl_form_submit'.tr(),
                    onSubmit: (code, seats, zone) async {
                      final ok = await widget.cubit.updateTable(
                        table.id,
                        code: code,
                        seats: seats,
                        zone: zone,
                        clearZone: zone == null,
                      );
                      if (ok && mounted) setState(() => _editing = false);
                      return ok;
                    },
                  )
                else if (widget.manageable && table != null)
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('sheet_edit'),
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text('tbl_edit'.tr()),
                        onPressed: () => setState(() => _editing = true),
                      ),
                      OutlinedButton.icon(
                        key: const Key('sheet_toggle'),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: Text('tbl_toggle_status'.tr()),
                        onPressed: () => widget.cubit.toggleStatus(table),
                      ),
                      OutlinedButton.icon(
                        key: const Key('sheet_delete'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text('tbl_delete'.tr()),
                        // Client-side gate for the known blocker (an open
                        // order). The server's 409 stays authoritative — a
                        // table blocked by an active reservation still
                        // reaches the API and its message is surfaced.
                        onPressed: table.isOccupied ? null : () => _confirmDelete(table),
                      ),
                    ],
                  ),
                if (widget.manageable && table != null && table.isOccupied)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      'tbl_delete_blocked'.tr(),
                      key: const Key('sheet_delete_blocked'),
                      style: TextStyles.font12DarkGray400Weight(context)
                          .copyWith(color: ColorsManager.errorColor),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(PanelPhysicalTable table) {
    if (table.isOccupied) return 'tbl_occupied'.tr();
    switch (table.status) {
      case 'reserved':
        return 'tbl_reserved'.tr();
      case 'inactive':
        return 'tbl_inactive'.tr();
      case 'unavailable':
        return 'tbl_unavailable'.tr();
      default:
        return 'tbl_available'.tr();
    }
  }

  void _openOrders() {
    widget.onOpenOrders?.call();
    Navigator.of(context).pop();
  }

  /// Destructive delete: the action sheet confirms before the repo is hit.
  Future<void> _confirmDelete(PanelPhysicalTable table) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => Container(
        key: const Key('delete_confirm'),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'tbl_delete_confirm_title'.tr(),
              style: TextStyles.font16Black500Weight(context),
            ),
            SizedBox(height: 8.h),
            Text(
              'tbl_delete_confirm_message'.tr(),
              style: TextStyles.font12DarkGray400Weight(context),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('delete_confirm_no'),
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text('tbl_delete_confirm_no'.tr()),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: FilledButton(
                    key: const Key('delete_confirm_yes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorsManager.errorColor,
                    ),
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text('tbl_delete_confirm_yes'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await widget.cubit.deleteTable(table.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// The shared table form (code / seats / zone) used by the detail sheet's
/// edit action and by the add-table sheet.
class _TableForm extends StatefulWidget {
  const _TableForm({
    required this.initialCode,
    required this.initialSeats,
    required this.initialZone,
    required this.zoneSuggestions,
    required this.submitLabel,
    required this.onSubmit,
    this.closeOnSuccess = false,
  });

  final String initialCode;
  final String initialSeats;
  final String initialZone;
  final List<String> zoneSuggestions;
  final String submitLabel;
  final Future<bool> Function(String code, int seats, String? zone) onSubmit;
  final bool closeOnSuccess;

  @override
  State<_TableForm> createState() => _TableFormState();
}

class _TableFormState extends State<_TableForm> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initialCode);
  late final TextEditingController _seats =
      TextEditingController(text: widget.initialSeats);
  late final TextEditingController _zone =
      TextEditingController(text: widget.initialZone);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _seats.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    final seats = int.tryParse(_seats.text.trim());
    if (code.isEmpty) {
      setState(() => _error = 'tbl_form_invalid_code'.tr());
      return;
    }
    if (seats == null || seats < 1 || seats > 50) {
      setState(() => _error = 'tbl_form_invalid_seats'.tr());
      return;
    }
    final zone = _zone.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSubmit(
      code,
      seats,
      zone.isEmpty ? null : zone,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'tbl_form_failed'.tr();
    });
    if (ok && widget.closeOnSuccess) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('form_code'),
          controller: _code,
          decoration: InputDecoration(labelText: 'tbl_form_code'.tr()),
        ),
        SizedBox(height: 8.h),
        TextField(
          key: const Key('form_seats'),
          controller: _seats,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'tbl_form_seats'.tr()),
        ),
        SizedBox(height: 8.h),
        TextField(
          key: const Key('form_zone'),
          controller: _zone,
          decoration: InputDecoration(labelText: 'tbl_form_zone'.tr()),
        ),
        if (widget.zoneSuggestions.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final zone in widget.zoneSuggestions)
                ActionChip(
                  key: Key('form_zone_chip_$zone'),
                  label: Text(zone),
                  onPressed: () => setState(() => _zone.text = zone),
                ),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              _error!,
              key: const Key('form_error'),
              style: TextStyles.font12DarkGray400Weight(context)
                  .copyWith(color: ColorsManager.errorColor),
            ),
          ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('form_submit'),
            onPressed: _busy ? null : _submit,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
