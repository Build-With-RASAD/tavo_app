// lib/feature/restaurant_panel/ui/screens/staff_screen.dart
//
// Wave C (Task 15): real staff list — member cards, add/edit bottom sheet
// with the 14-permission matrix, suspend/activate/delete through an action
// sheet. Same class name + constructor as the Task 11 placeholder so
// `shell_defaults.dart` keeps compiling; `registerStaffModule()` swaps the
// `staff` hub entry for this screen.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_staff/data/model/staff_models.dart';
import 'package:tavo/feature/panel_staff/data/repo/staff_panel_repo.dart';
import 'package:tavo/feature/panel_staff/ui/logic/staff_panel_cubit.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Mutation gate: owner/manager, or anyone holding `full_access` /
/// `manage_staff` (mirrors `StaffRestaurant.canManage` plus `manage_staff`).
bool _canManageStaff(StaffRestaurant venue) =>
    venue.role == 'owner' ||
    venue.role == 'manager' ||
    venue.permissions.contains('full_access') ||
    venue.permissions.contains('manage_staff');

/// Staff panel team list: builds its own [StaffPanelCubit] through get_it
/// (mirroring `DashboardScreen`) and drives the three async states with
/// [ListSkeleton] / [ErrorStateView] / content. Mutation failures surface as
/// a SnackBar while every row stays on screen
/// (`StaffPanelLoaded.actionError`).
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    final manageable = _canManageStaff(venue);
    return BlocProvider(
      create: (_) => StaffPanelCubit(
        GetIt.instance<StaffPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocConsumer<StaffPanelCubit, StaffPanelState>(
        listener: (context, state) {
          if (state is StaffPanelLoaded && state.actionError != null) {
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
          final cubit = context.read<StaffPanelCubit>();
          return Scaffold(
            body: SafeArea(child: _buildBody(context, cubit, state)),
            floatingActionButton: manageable
                ? FloatingActionButton(
                    key: const ValueKey('add_staff'),
                    onPressed: () => _openStaffSheet(context, cubit, null),
                    child: const Icon(Iconsax.add),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    StaffPanelCubit cubit,
    StaffPanelState state,
  ) {
    if (state is StaffPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: cubit.load,
          ),
          SizedBox(height: 8.h),
        ],
      );
    }
    if (state is StaffPanelLoaded) {
      return Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildList(context, cubit, state)),
        ],
      );
    }
    // StaffPanelInitial / StaffPanelLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'staff'.tr(),
              style: TextStyles.font20Black500Weight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    StaffPanelCubit cubit,
    StaffPanelLoaded state,
  ) {
    if (state.members.isEmpty) {
      return EmptyStateView(
        icon: Iconsax.user_square,
        title: 'empty_staff_title'.tr(),
        message: 'empty_staff_message'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: state.members.length,
        itemBuilder: (context, index) {
          final member = state.members[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _StaffMemberCard(
              key: ValueKey('staff_card_${member.id}'),
              member: member,
              acting: state.actionId == member.id,
              manageable: _canManageStaff(venue),
              onActions: () => _openActions(context, cubit, member),
            ),
          );
        },
      ),
    );
  }

  /// Row overflow → action sheet (Suspend/Activate, Edit, Delete staff).
  Future<void> _openActions(
    BuildContext context,
    StaffPanelCubit cubit,
    PanelStaffMember member,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _StaffActionsSheet(
        member: member,
        onSuspend: () {
          cubit.setStatus(member, 'suspended');
          Navigator.of(sheetContext).pop();
        },
        onActivate: () {
          cubit.setStatus(member, 'active');
          Navigator.of(sheetContext).pop();
        },
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _openStaffSheet(context, cubit, member);
        },
        onDelete: () async {
          Navigator.of(sheetContext).pop();
          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => const _DeleteStaffSheet(),
          );
          if (confirmed == true) cubit.removeStaff(member);
        },
      ),
    );
  }

  void _openStaffSheet(
    BuildContext context,
    StaffPanelCubit cubit,
    PanelStaffMember? member,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StaffSheet(cubit: cubit, member: member),
    );
  }
}

/// One staff row: name, phone, permission count, role + status chips and —
/// when the role may manage staff — the overflow action button.
class _StaffMemberCard extends StatelessWidget {
  const _StaffMemberCard({
    super.key,
    required this.member,
    required this.acting,
    required this.manageable,
    required this.onActions,
  });

  final PanelStaffMember member;
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
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.font14Black400Weight(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  member.phone,
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${member.permissions.length} ${'permissions'.tr()}',
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    _RoleChip(role: member.role),
                    SizedBox(width: 8.w),
                    StatusBadge(status: member.status),
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
              key: ValueKey('actions_${member.id}'),
              icon: const Icon(Iconsax.more),
              onPressed: onActions,
            ),
        ],
      ),
    );
  }
}

/// Role pill: `manager` → `manager` key, anything else → `staff_member` key.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: ColorsManager.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        (role == 'manager' ? 'manager' : 'staff_member').tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ColorsManager.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Row action sheet: Suspend (or Activate when `inactive`), Edit, Delete.
class _StaffActionsSheet extends StatelessWidget {
  const _StaffActionsSheet({
    required this.member,
    required this.onSuspend,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  final PanelStaffMember member;
  final VoidCallback onSuspend;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated Container): the action rows are ListTiles
    // and paint their ink on the nearest Material ancestor — a background
    // color on an intermediate DecoratedBox would hide those effects and
    // trip a framework assertion in debug builds.
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
              member.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            if (member.status == 'inactive')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Iconsax.play),
                title: Text('activate'.tr()),
                onTap: onActivate,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Iconsax.pause),
                title: Text('suspend'.tr()),
                onTap: onSuspend,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Iconsax.edit_2),
              title: Text('edit_staff'.tr()),
              onTap: onEdit,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Iconsax.trash),
              title: Text('delete_staff'.tr()),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nested delete confirmation: only sends `true` back on explicit confirm.
class _DeleteStaffSheet extends StatelessWidget {
  const _DeleteStaffSheet();

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
            'delete_staff'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            'delete_staff_confirm'.tr(),
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

/// Add/edit staff bottom sheet: name + phone on add, role dropdown, the
/// 14-permission matrix with a select-all (`full_access`) shortcut, save.
///
/// Layout keeps the name/phone/role/shortcut fields and the save button
/// pinned while only the permission list scrolls, so every keyed control is
/// tappable without scrolling.
class _StaffSheet extends StatefulWidget {
  const _StaffSheet({required this.cubit, required this.member});

  final StaffPanelCubit cubit;
  final PanelStaffMember? member;

  @override
  State<_StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<_StaffSheet> {
  bool get _isAdd => widget.member == null;

  late final TextEditingController _name =
      TextEditingController(text: widget.member?.name ?? '');
  late final TextEditingController _phone = TextEditingController();
  late String _role = widget.member?.role ?? 'staff';
  late Set<String> _permissions = {...?widget.member?.permissions};

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final allSelected =
        _permissions.length == kPanelPermissions.length &&
        kPanelPermissions.every(_permissions.contains);
    // Material (not a decorated Container): the permission rows are
    // CheckboxListTiles and paint their ink on the nearest Material
    // ancestor — a background color on an intermediate DecoratedBox would
    // hide those effects and trip a framework assertion in debug builds.
    return Material(
      color: ColorsManager.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_isAdd ? 'add_staff' : 'edit_staff').tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16.h),
              if (_isAdd) ...[
                TextField(
                  key: const ValueKey('staff_name'),
                  controller: _name,
                  decoration: InputDecoration(labelText: 'staff_name'.tr()),
                ),
                SizedBox(height: 12.h),
                TextField(
                  key: const ValueKey('staff_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'staff_phone'.tr()),
                ),
                SizedBox(height: 12.h),
              ] else
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    widget.member!.name,
                    style: TextStyles.font14Black400Weight(context),
                  ),
                ),
              DropdownButtonFormField<String>(
                key: const ValueKey('staff_role'),
                initialValue: _role,
                decoration: InputDecoration(labelText: 'role'.tr()),
                items: [
                  DropdownMenuItem(
                      value: 'staff', child: Text('staff_member'.tr())),
                  DropdownMenuItem(
                      value: 'manager', child: Text('manager'.tr())),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              CheckboxListTile(
                key: const ValueKey('perm_full_access_shortcut'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('select_all_permissions'.tr()),
                value: allSelected,
                onChanged: (_) => setState(() {
                  _permissions =
                      allSelected ? {} : kPanelPermissions.toSet();
                }),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final permission in kPanelPermissions)
                      CheckboxListTile(
                        key: ValueKey('perm_$permission'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: Text(permission),
                        value: _permissions.contains(permission),
                        onChanged: (_) => setState(() {
                          if (_permissions.contains(permission)) {
                            _permissions.remove(permission);
                          } else {
                            _permissions.add(permission);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save_staff'),
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

  void _save() {
    if (_isAdd) {
      widget.cubit.addStaff(
        phone: _phone.text.trim(),
        name: _name.text.trim(),
        role: _role,
        permissions: _permissions.toList(),
      );
    } else {
      widget.cubit.saveStaff(
        widget.member!,
        role: _role,
        permissions: _permissions.toList(),
      );
    }
    Navigator.of(context).pop();
  }
}
