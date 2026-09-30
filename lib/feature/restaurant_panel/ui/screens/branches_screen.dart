// lib/feature/restaurant_panel/ui/screens/branches_screen.dart
//
// Wave D (Task 19): real branches list — branch cards with primary/inactive
// chips, create/edit bottom sheet with a compact 7-day hours editor,
// activate/deactivate/delete through an action sheet. Same class name +
// constructor as the Task 11 placeholder so `shell_defaults.dart` keeps
// compiling; `registerBranchesModule()` swaps the `branches` hub entry for
// this screen.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_branches/data/model/branch_models.dart';
import 'package:tavo/feature/panel_branches/data/repo/branches_panel_repo.dart';
import 'package:tavo/feature/panel_branches/ui/logic/branches_panel_cubit.dart';

/// Weekday order for the hours editor (matches the backend day map).
const _weekDays = ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri'];

Map<String, Map<String, dynamic>> _defaultHours() => {
      for (final d in _weekDays)
        d: {'open': '09:00', 'close': '23:00', 'isClosed': false},
    };

/// Mutation gate: owner/manager, or anyone holding `full_access` /
/// `manage_settings` (mirrors `StaffRestaurant.canManage` plus settings).
bool _canManageBranches(StaffRestaurant venue) =>
    venue.role == 'owner' ||
    venue.role == 'manager' ||
    venue.permissions.contains('full_access') ||
    venue.permissions.contains('manage_settings');

/// Branches panel list: builds its own [BranchesPanelCubit] through get_it
/// (mirroring `DashboardScreen`) and drives the three async states with
/// [ListSkeleton] / [ErrorStateView] / content. Mutation failures surface as
/// a SnackBar while every row stays on screen
/// (`BranchesPanelLoaded.actionError`).
class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    final manageable = _canManageBranches(venue);
    return BlocProvider(
      create: (_) => BranchesPanelCubit(
        GetIt.instance<BranchesPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocConsumer<BranchesPanelCubit, BranchesPanelState>(
        listener: (context, state) {
          if (state is BranchesPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                margin: EdgeInsets.all(16.w),
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<BranchesPanelCubit>();
          return Scaffold(
            body: SafeArea(child: _buildBody(context, cubit, state)),
            floatingActionButton: manageable
                ? FloatingActionButton(
                    key: const ValueKey('add_branch'),
                    onPressed: () => _openBranchSheet(context, cubit, null),
                    child: const Icon(Icons.add),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BranchesPanelCubit cubit,
    BranchesPanelState state,
  ) {
    if (state is BranchesPanelError) {
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
    if (state is BranchesPanelLoaded) {
      return Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildList(context, cubit, state)),
        ],
      );
    }
    // BranchesPanelInitial / BranchesPanelLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'branches'.tr(),
              style: TextStyles.font20Black500Weight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    BranchesPanelCubit cubit,
    BranchesPanelLoaded state,
  ) {
    if (state.branches.isEmpty) {
      return EmptyStateView(
        icon: Icons.store_outlined,
        title: 'empty_branches_title'.tr(),
        message: 'empty_branches_message'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: state.branches.length,
        itemBuilder: (context, index) {
          final branch = state.branches[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _BranchCard(
              key: ValueKey('branch_card_${branch.id}'),
              branch: branch,
              acting: state.actionId == branch.id,
              manageable: _canManageBranches(venue),
              onActions: () => _openActions(context, cubit, branch),
            ),
          );
        },
      ),
    );
  }

  /// Row overflow → action sheet (Edit / Activate|Deactivate / Delete).
  Future<void> _openActions(
    BuildContext context,
    BranchesPanelCubit cubit,
    PanelBranch branch,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BranchActionsSheet(
        branch: branch,
        onToggleActive: () {
          cubit.setActive(branch, !branch.isActive);
          Navigator.of(sheetContext).pop();
        },
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _openBranchSheet(context, cubit, branch);
        },
        onDelete: () async {
          Navigator.of(sheetContext).pop();
          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => _DeleteBranchSheet(branch: branch),
          );
          if (confirmed == true) cubit.remove(branch);
        },
      ),
    );
  }

  void _openBranchSheet(
    BuildContext context,
    BranchesPanelCubit cubit,
    PanelBranch? branch,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BranchSheet(cubit: cubit, branch: branch),
    );
  }
}

/// One branch row: English name, Arabic subtitle, city/region line,
/// `primary` / `inactive` chips and — when the role may manage branches —
/// the overflow action button.
class _BranchCard extends StatelessWidget {
  const _BranchCard({
    super.key,
    required this.branch,
    required this.acting,
    required this.manageable,
    required this.onActions,
  });

  final PanelBranch branch;
  final bool acting;
  final bool manageable;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.enName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.font14Black400Weight(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  branch.arName,
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${branch.city}, ${branch.region}',
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    if (branch.isMain) ...[
                      _BranchChip(label: 'primary'.tr(), primary: true),
                      SizedBox(width: 8.w),
                    ],
                    if (!branch.isActive)
                      _BranchChip(label: 'inactive'.tr()),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
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
              key: ValueKey('actions_${branch.id}'),
              icon: const Icon(Icons.more_vert),
              onPressed: onActions,
            ),
        ],
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.label, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: primary
            ? ColorsManager.primaryColor.withValues(alpha: 0.12)
            : ColorsManager.grey100,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: primary
              ? ColorsManager.primaryColor
              : ColorsManager.dark500,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Row action sheet: Activate (or Deactivate when active), Edit, Delete.
class _BranchActionsSheet extends StatelessWidget {
  const _BranchActionsSheet({
    required this.branch,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final PanelBranch branch;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorsManager.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch.enName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(branch.isActive
                  ? Icons.pause_outlined
                  : Icons.play_arrow_outlined),
              title: Text(
                branch.isActive ? 'deactivate'.tr() : 'activate'.tr(),
              ),
              onTap: onToggleActive,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: Text('edit_branch'.tr()),
              onTap: onEdit,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: Text('delete_branch'.tr()),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nested delete confirmation: only sends `true` back on explicit confirm.
class _DeleteBranchSheet extends StatelessWidget {
  const _DeleteBranchSheet({required this.branch});

  final PanelBranch branch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'delete_branch'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            branch.enName,
            style: TextStyles.font12DarkGray400Weight(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('confirm_delete'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorsManager.redButton,
                    foregroundColor: ColorsManager.white,
                  ),
                  child: Text('delete'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add/edit branch bottom sheet: ar/en names, address/city/region,
/// comma-separated phones, email/whatsapp, numeric lat/lng, manager name
/// and a compact 7-day hours editor.
///
/// Layout keeps the title and the save button pinned while only the form
/// scrolls, so every keyed control is tappable without scrolling.
class _BranchSheet extends StatefulWidget {
  const _BranchSheet({required this.cubit, required this.branch});

  final BranchesPanelCubit cubit;
  final PanelBranch? branch;

  @override
  State<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<_BranchSheet> {
  bool get _isAdd => widget.branch == null;

  late final TextEditingController _nameAr =
      TextEditingController(text: widget.branch?.arName ?? '');
  late final TextEditingController _nameEn =
      TextEditingController(text: widget.branch?.enName ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.branch?.address ?? '');
  late final TextEditingController _city =
      TextEditingController(text: widget.branch?.city ?? '');
  late final TextEditingController _region =
      TextEditingController(text: widget.branch?.region ?? '');
  late final TextEditingController _phones = TextEditingController(
      text: widget.branch == null ? '' : widget.branch!.phones.join(', '));
  late final TextEditingController _email =
      TextEditingController(text: widget.branch?.email ?? '');
  late final TextEditingController _whatsapp =
      TextEditingController(text: widget.branch?.whatsapp ?? '');
  late final TextEditingController _lat = TextEditingController(
      text: widget.branch?.latitude?.toString() ?? '');
  late final TextEditingController _lng = TextEditingController(
      text: widget.branch?.longitude?.toString() ?? '');
  late final TextEditingController _manager =
      TextEditingController(text: widget.branch?.managerName ?? '');

  late final Map<String, Map<String, dynamic>> _hours = widget.branch == null
      ? _defaultHours()
      : {
          for (final d in _weekDays)
            d: Map<String, dynamic>.from(
              widget.branch!.workingHours[d] ??
                  {'open': '09:00', 'close': '23:00', 'isClosed': false},
            ),
        };

  late final Map<String, TextEditingController> _openCtrls = {
    for (final d in _weekDays)
      d: TextEditingController(text: '${_hours[d]!['open'] ?? ''}'),
  };
  late final Map<String, TextEditingController> _closeCtrls = {
    for (final d in _weekDays)
      d: TextEditingController(text: '${_hours[d]!['close'] ?? ''}'),
  };

  String? _error;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _address.dispose();
    _city.dispose();
    _region.dispose();
    _phones.dispose();
    _email.dispose();
    _whatsapp.dispose();
    _lat.dispose();
    _lng.dispose();
    _manager.dispose();
    for (final c in _openCtrls.values) {
      c.dispose();
    }
    for (final c in _closeCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: ColorsManager.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_isAdd ? 'add_branch' : 'edit_branch').tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey('branch_name_ar'),
                        controller: _nameAr,
                        decoration: InputDecoration(
                            labelText: 'branch_name_ar'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_name_en'),
                        controller: _nameEn,
                        decoration: InputDecoration(
                            labelText: 'branch_name_en'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_address'),
                        controller: _address,
                        decoration: InputDecoration(
                            labelText: 'branch_address'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_city'),
                        controller: _city,
                        decoration: InputDecoration(
                            labelText: 'branch_city'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_region'),
                        controller: _region,
                        decoration: InputDecoration(
                            labelText: 'branch_region'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_phones'),
                        controller: _phones,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            labelText: 'branch_phones'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                            labelText: 'branch_email'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_whatsapp'),
                        controller: _whatsapp,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                            labelText: 'branch_whatsapp'.tr()),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('branch_lat'),
                              controller: _lat,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                  labelText: 'branch_lat'.tr()),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('branch_lng'),
                              controller: _lng,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                  labelText: 'branch_lng'.tr()),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        key: const ValueKey('branch_manager'),
                        controller: _manager,
                        decoration: InputDecoration(
                            labelText: 'branch_manager'.tr()),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'working_hours'.tr(),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      for (final day in _weekDays) _hoursRow(day),
                      if (_error != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          _error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save_branch'),
                  onPressed: _save,
                  child: Text('save'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoursRow(String day) {
    final row = _hours[day]!;
    final closed = row['isClosed'] == true;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 48.w,
            child: Text(
              day,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: ValueKey('branch_wh_${day}_open'),
              enabled: !closed,
              controller: _openCtrls[day],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              key: ValueKey('branch_wh_${day}_close'),
              enabled: !closed,
              controller: _closeCtrls[day],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          Switch(
            key: ValueKey('branch_wh_closed_$day'),
            value: closed,
            onChanged: (v) => setState(() => row['isClosed'] = v),
          ),
        ],
      ),
    );
  }

  List<String> _parsePhones(String raw) => raw
      .split(RegExp(r'[,،]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _save() {
    final arName = _nameAr.text.trim();
    final enName = _nameEn.text.trim();
    final address = _address.text.trim();
    final city = _city.text.trim();
    final region = _region.text.trim();
    final latRaw = _lat.text.trim();
    final lngRaw = _lng.text.trim();
    final lat = latRaw.isEmpty ? null : double.tryParse(latRaw);
    final lng = lngRaw.isEmpty ? null : double.tryParse(lngRaw);
    if (arName.isEmpty ||
        enName.isEmpty ||
        address.isEmpty ||
        city.isEmpty ||
        region.isEmpty ||
        (latRaw.isNotEmpty && lat == null) ||
        (lngRaw.isNotEmpty && lng == null)) {
      setState(() => _error = 'required'.tr());
      return;
    }
    final email = _email.text.trim();
    final whatsapp = _whatsapp.text.trim();
    final manager = _manager.text.trim();
    final hours = <String, Map<String, dynamic>>{
      for (final d in _weekDays)
        d: {
          'open': _openCtrls[d]!.text.trim(),
          'close': _closeCtrls[d]!.text.trim(),
          'isClosed': _hours[d]!['isClosed'] == true,
        },
    };
    widget.cubit.save(
      id: widget.branch?.id,
      arName: arName,
      enName: enName,
      address: address,
      city: city,
      region: region,
      phones: _parsePhones(_phones.text),
      email: email.isEmpty ? null : email,
      whatsapp: whatsapp.isEmpty ? null : whatsapp,
      latitude: lat,
      longitude: lng,
      workingHours: hours,
      managerName: manager.isEmpty ? null : manager,
    );
    Navigator.of(context).pop();
  }
}
