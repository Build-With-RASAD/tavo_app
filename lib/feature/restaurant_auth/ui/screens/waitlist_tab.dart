// lib/feature/restaurant_auth/ui/screens/waitlist_tab.dart
//
// Wave C (Task 17): real waitlist queue — skeleton → filter chips → cards
// with per-row transitions; publishes the shell tab badge through the
// `waitlistBadgeCount` global on every successful load.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'package:tavo/feature/panel_waitlist/data/repo/waitlist_panel_repo.dart';
import 'package:tavo/feature/panel_waitlist/ui/logic/waitlist_panel_cubit.dart';

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
            body: SafeArea(child: _buildBody(context, cubit, state)),
          );
        },
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

/// One queue row: ticket code, customer, guests, phone, waited time, status
/// chip, notes and — when the role may manage — the legal transition
/// buttons for the entry's status (or a per-row spinner while one runs).
class _WaitlistCard extends StatelessWidget {
  const _WaitlistCard({
    super.key,
    required this.entry,
    required this.acting,
    required this.manageable,
    required this.onAction,
  });

  final PanelWaitlistEntry entry;
  final bool acting;
  final bool manageable;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions =
        manageable ? nextWaitlistActions(entry.status) : const <String>[];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${'ticket'.tr()}: ',
                style: textTheme.bodySmall,
              ),
              Text(
                entry.ticketCode,
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('status_${entry.status}'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.customerName,
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text('${entry.guestsCount} ${'guests'.tr()}'),
          Text(entry.customerPhone),
          Text('${'waited_min'.tr()} ${formatWaited(entry.waitedMinutes)}'),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(entry.notes!),
          ],
          if (acting)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final action in actions)
                    TextButton(
                      key: ValueKey(
                          'action_${entry.id}_${action.replaceAll('-', '_')}'),
                      onPressed: () => onAction(action),
                      child: Text(action.replaceAll('-', '_').tr()),
                    ),
                ],
              ),
            ),
        ],
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
