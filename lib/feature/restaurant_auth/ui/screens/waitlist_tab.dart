// lib/feature/restaurant_auth/ui/screens/waitlist_tab.dart
//
// Wave C (Task 17): real waitlist queue — skeleton → filter chips → cards
// with per-row transitions; publishes the shell tab badge through the
// `waitlistBadgeCount` global on every successful load.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'package:tavo/feature/panel_waitlist/data/repo/waitlist_panel_repo.dart';
import 'package:tavo/feature/panel_waitlist/ui/logic/waitlist_panel_cubit.dart';
import 'package:tavo/feature/panel_waitlist/ui/widgets/add_walkin_sheet.dart';

/// `12` → `12m`, `75` → `1h 15m` — waited time ticks only on rebuild
/// (no timer, so widget tests stay deterministic).
String formatWaited(int minutes) {
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// Staff panel waitlist queue for the venue.
///
/// Builds its own [WaitlistPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`: the shell only supplies the restaurant id and the
/// venue) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Mutation failures keep every row on screen
/// with the failure as an inline banner (`actionError`).
class WaitlistTab extends StatelessWidget {
  const WaitlistTab({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  bool get _canManage =>
      venue.role == 'owner' ||
      venue.role == 'manager' ||
      venue.permissions.contains('full_access') ||
      venue.permissions.contains('manage_reservations');

  @override
  Widget build(BuildContext context) {
    // The module repo is registered by `registerWaitlistModule()` (wired
    // into service_locator by the controller). When it isn't registered —
    // e.g. shell suites that predate the module — keep the Task 11
    // placeholder visual instead of throwing out of the whole shell
    // (IndexedStack mounts every tab).
    if (!GetIt.instance.isRegistered<WaitlistPanelRepo>()) {
      return Scaffold(
        body: SafeArea(
          child: EmptyStateView(
            icon: Icons.hourglass_empty_outlined,
            title: 'waitlist_empty'.tr(),
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) => WaitlistPanelCubit(
        GetIt.instance<WaitlistPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocBuilder<WaitlistPanelCubit, WaitlistPanelState>(
        builder: (context, state) {
          final cubit = context.read<WaitlistPanelCubit>();
          return Scaffold(
            // The queue's own "add a walk-in" action: the form lives with
            // the queue, so the new entry lands in the list right away.
            floatingActionButton: FloatingActionButton.extended(
              key: const ValueKey('waitlist_add_walkin'),
              onPressed: () => _openWalkinSheet(context, cubit),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text('dash_quick_waitlist'.tr()),
            ),
            body: SafeArea(child: _buildBody(context, cubit, state)),
          );
        },
      ),
    );
  }

  /// Opens the walk-in sheet with the tab's own cubit, so a created entry
  /// refreshes the queue behind it.
  Future<void> _openWalkinSheet(
    BuildContext context,
    WaitlistPanelCubit cubit,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const AddWalkinSheet(),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WaitlistPanelCubit cubit,
    WaitlistPanelState state,
  ) {
    if (state is WaitlistPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.load,
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    if (state is WaitlistPanelLoaded) {
      return Column(
        children: [
          _buildStatusChips(cubit, state.filterStatus),
          if (state.actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                state.actionError!,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ),
          Expanded(child: _buildList(context, cubit, state)),
        ],
      );
    }
    // WaitlistPanelInitial / WaitlistPanelLoading.
    return const ListSkeleton();
  }

  /// Server-side status filter chips (`all` = no `&status=` param).
  Widget _buildStatusChips(WaitlistPanelCubit cubit, String? filterStatus) {
    const filters = ['all', 'waiting', 'notified', 'confirmed', 'no_show', 'cancelled'];
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final status in filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('filter_waitlist_$status'),
                  label: Text(status == 'all'
                      ? 'all'.tr()
                      : 'status_$status'.tr()),
                  selected: (filterStatus ?? 'all') == status,
                  onSelected: (_) => cubit.setStatusFilter(
                      status == 'all' ? null : status),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WaitlistPanelCubit cubit,
    WaitlistPanelLoaded state,
  ) {
    if (state.entries.isEmpty) {
      return EmptyStateView(
        icon: Icons.hourglass_empty_outlined,
        title: 'waitlist_empty'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.entries.length,
        itemBuilder: (context, index) {
          final entry = state.entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WaitlistCard(
              key: ValueKey('wait_${entry.id}'),
              entry: entry,
              position: waitlistQueuePositions(state.entries)[entry.id],
              acting: state.actionId == entry.id,
              manageable: _canManage,
              onAction: (action) =>
                  _runAction(context, cubit, entry, action),
            ),
          );
        },
      ),
    );
  }

  /// `cancel`/`no_show` confirm through an action sheet first;
  /// `notify`/`confirm` fire directly.
  Future<void> _runAction(
    BuildContext context,
    WaitlistPanelCubit cubit,
    PanelWaitlistEntry entry,
    String action,
  ) async {
    if (action == 'cancel' || action == 'no-show') {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const _ConfirmActionSheet(),
      );
      if (confirmed != true || !context.mounted) return;
    }
    cubit.transition(entry, action);
  }
}

/// One queue row, built around the two numbers a host actually watches:
/// the queue position (`#2`) and how long the party has been waiting
/// (colour-coded: green < 10m, amber < 20m, red after).
///
/// Also carries the ticket code, party size, phone, guest notes and — when
/// the role may manage — the legal transition buttons for the entry's status
/// (or a per-row spinner while one runs).
class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard({
    super.key,
    required this.entry,
    required this.position,
    required this.acting,
    required this.manageable,
    required this.onAction,
  });

  final PanelWaitlistEntry entry;

  /// 1-based place in the live queue; null once the party leaves the line.
  final int? position;

  final bool acting;
  final bool manageable;
  final void Function(String action) onAction;

  Color get _heat {
    final minutes = entry.waitedMinutes;
    if (minutes >= 20) return const Color(0xFFC62828);
    if (minutes >= 10) return const Color(0xFFB26A00);
    return const Color(0xFF22A83A);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions =
        manageable ? nextWaitlistActions(entry.status) : const <String>[];
    final note = [
      if (entry.notes != null && entry.notes!.isNotEmpty) entry.notes!,
      if (entry.specialRequests != null && entry.specialRequests!.isNotEmpty)
        entry.specialRequests!,
    ].join(' · ');

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QueueBadge(position: position, heat: _heat),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    StatusBadge(
                      status: entry.status,
                      label: 'status_${entry.status}'.tr(),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _QueuePill(
                      icon: Iconsax.people,
                      label: '${entry.guestsCount} ${'guests'.tr()}',
                    ),
                    _QueuePill(
                      icon: Iconsax.ticket,
                      label: entry.ticketCode,
                    ),
                    _QueuePill(
                      icon: Iconsax.clock,
                      label:
                          '${'waited_min'.tr()} ${formatWaited(entry.waitedMinutes)}',
                      color: _heat,
                    ),
                  ],
                ),
                if (entry.customerPhone.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    entry.customerPhone,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: ColorsManager.darkGray300,
                    ),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(10.r),
                      border: const Border(
                        left: BorderSide(
                          color: Color(0xFFB0B7C3),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        height: 1.45,
                        color: const Color(0xFF3D4552),
                      ),
                    ),
                  ),
                ],
                if (acting)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (actions.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        for (final action in actions)
                          _ActionButton(
                            key: ValueKey(
                              'action_${entry.id}_${action.replaceAll('-', '_')}',
                            ),
                            action: action,
                            onPressed: () => onAction(action),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The big queue number. Head of the line gets the gold surface, everyone
/// else a neutral one — so "#1" is visible across the room.
class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.position, required this.heat});

  final int? position;
  final Color heat;

  @override
  Widget build(BuildContext context) {
    final head = position == 1;

    return Container(
      width: 54.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: head
            ? ColorsManager.primaryColor.withValues(alpha: 0.16)
            : ColorsManager.grey100,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: head
              ? ColorsManager.primaryColor.withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Text(
            position == null ? '—' : '#$position',
            style: TextStyle(
              fontSize: 17.sp,
              height: 1,
              fontWeight: FontWeight.w800,
              color: ColorsManager.black,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'queue_position'.tr(),
            style: TextStyle(
              fontSize: 9.sp,
              color: ColorsManager.darkGray300,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuePill extends StatelessWidget {
  const _QueuePill({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? ColorsManager.darkGray;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color == null
            ? ColorsManager.grey100
            : color!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: foreground),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// `confirm` is the happy path (seat the party), so it is the only filled
/// button; the rest stay outlined. Keys stay `action_<id>_<action>` so the
/// existing widget tests keep addressing the same controls.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.action,
    required this.onPressed,
  });

  final String action;
  final VoidCallback onPressed;

  String get _label =>
      action == 'confirm' ? 'seat_guest'.tr() : action.replaceAll('-', '_').tr();

  @override
  Widget build(BuildContext context) {
    final primary = action == 'confirm';
    final foreground = primary ? ColorsManager.black : ColorsManager.darkGray;

    return SizedBox(
      height: 32.h,
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: ColorsManager.primaryColor,
                foregroundColor: foreground,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                textStyle:
                    TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              ),
              child: Text(_label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: const BorderSide(color: ColorsManager.grey200),
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                textStyle:
                    TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
              child: Text(_label),
            ),
    );
  }
}

/// Confirm sheet for the destructive waitlist actions (`cancel`/`no_show`):
/// only sends `true` back when the confirmation button is tapped.
class _ConfirmActionSheet extends StatelessWidget {
  const _ConfirmActionSheet();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'confirm_action_title'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('confirm_action_yes'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('confirm_action_yes'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
