// lib/feature/restaurant_panel/ui/screens/tables_screen.dart
//
// Wave C (Task 14): real table-type chips + the custom fractional floor-plan
// editor. Replaces the Task 11 placeholder in place (same class name +
// constructor) so `shell_defaults.dart` keeps compiling; the `tables` hub
// entry is swapped via `registerTablesModule()`.
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
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/logic/tables_panel_cubit.dart';

/// Staff panel floor plan: table-type chips, a draggable fractional canvas
/// (`Positioned` tables at `x,y ∈ [0,1]`, unpositioned tables in the tray),
/// a role-gated save-layout action and per-table status toggles.
///
/// Builds its own [TablesPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Save/status failures surface as a SnackBar
/// while the editor keeps its positions (`TablesPanelLoaded.actionError`).
class TablesScreen extends StatefulWidget {
  const TablesScreen(
      {super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  /// Tracks the previous `saving` flag so the save-success toast fires only
  /// on the `saving: true → false` transition (the loaded state carries no
  /// saved flag of its own).
  bool _wasSaving = false;

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
            _buildHeader(context),
            _buildTypeChips(cubit, state),
            SizedBox(height: 8.h),
            _buildEditor(cubit, state, manageable),
            SizedBox(height: 8.h),
            _buildTray(state),
            SizedBox(height: 8.h),
            _buildStatusList(cubit, state, manageable),
            if (manageable)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Text(
        'floor_plan'.tr(),
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w600),
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

  /// The fractional canvas: positioned tables as 40×40 `Positioned` chips,
  /// dragged with `onPanUpdate` (fractions recomputed from the box size).
  Widget _buildEditor(
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                for (final table in positioned)
                  Positioned(
                    left: table.x! * w - 20,
                    top: table.y! * h - 20,
                    child: GestureDetector(
                      key: Key('table_${table.id}'),
                      onPanUpdate: manageable
                          ? (details) => cubit.moveTable(
                                table.id,
                                (table.x! * w + details.delta.dx) / w,
                                (table.y! * h + details.delta.dy) / h,
                              )
                          : null,
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          table.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
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
        border: Border.all(color: Colors.grey.shade300),
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

  /// Per-table seats + status rows. Rows name no codes (the editor and tray
  /// already render each code exactly once) — status only.
  Widget _buildStatusList(
    TablesPanelCubit cubit,
    TablesPanelLoaded state,
    bool manageable,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'table_status'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          for (final table in state.tables)
            _StatusRow(
              table: table,
              textTheme: textTheme,
              acting: state.actionId == table.id,
              manageable: manageable,
              onToggle: () => cubit.toggleStatus(table),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.table,
    required this.textTheme,
    required this.acting,
    required this.manageable,
    required this.onToggle,
  });

  final PanelPhysicalTable table;
  final TextTheme textTheme;
  final bool acting;
  final bool manageable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${'seats'.tr()}: ${table.seats} • ${table.status}',
              style: textTheme.bodyMedium,
            ),
          ),
          if (acting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (manageable)
            IconButton(
              key: ValueKey('status_${table.id}'),
              icon: Icon(
                table.status == 'available'
                    ? Icons.toggle_on
                    : Icons.toggle_off,
                size: 28,
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
