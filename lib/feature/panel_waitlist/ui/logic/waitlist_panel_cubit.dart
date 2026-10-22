// lib/feature/panel_waitlist/ui/logic/waitlist_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import '../../data/model/waitlist_models.dart';
import '../../data/repo/waitlist_panel_repo.dart';
import 'waitlist_panel_state.dart';

export 'waitlist_panel_state.dart';

/// Staff panel waitlist queue: server-side status filter and per-row
/// notify/confirm/no-show/cancel transitions.
///
/// Error style mirrors `PanelMenuCubit` (plain strings): `load` failures emit
/// [WaitlistPanelError]; transition/filter failures keep the loaded queue and
/// surface a transient [WaitlistPanelLoaded.actionError] beside it.
///
/// Every successful load publishes the shell tab badge through the
/// [waitlistBadgeCount] global: the count of `waiting|notified` entries on
/// the current page.
class WaitlistPanelCubit extends Cubit<WaitlistPanelState> {
  WaitlistPanelCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const WaitlistPanelInitial());

  final WaitlistPanelRepo _repo;
  final String restaurantId;

  /// Server-side filter, mirrored onto [WaitlistPanelLoaded.filterStatus]
  /// (`null` = all, no `&status=` param). Kept on the cubit so [load] can
  /// retry the filtered page after an [WaitlistPanelError].
  String? _status;

  Future<void> load() async {
    if (isClosed) return;
    emit(const WaitlistPanelLoading());
    try {
      final out = await _repo.getWaitlist(
        restaurantId,
        page: 1,
        status: _status,
      );
      if (isClosed) return;
      _publishBadge(out.entries);
      emit(WaitlistPanelLoaded(
        entries: out.entries,
        page: out.page,
        pages: out.pages,
        total: out.total,
        filterStatus: _status,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(WaitlistPanelError(_message(e)));
    }
  }

  /// Status chips: flips the server-side `&status=` filter and refetches
  /// from page 1 (`null`/`'all'` = no filter param).
  Future<void> setStatusFilter(String? status) async {
    final next = status == 'all' ? null : status;
    final s = state;
    if (s is WaitlistPanelLoaded && s.filterStatus == next) return;
    _status = next;
    if (s is! WaitlistPanelLoaded) {
      await load();
      return;
    }
    emit(const WaitlistPanelLoading());
    try {
      final out = await _repo.getWaitlist(
        restaurantId,
        page: 1,
        status: _status,
      );
      if (isClosed) return;
      _publishBadge(out.entries);
      emit(WaitlistPanelLoaded(
        entries: out.entries,
        page: out.page,
        pages: out.pages,
        total: out.total,
        filterStatus: _status,
      ));
    } catch (e) {
      if (isClosed) return;
      // Keep the previous page on screen with the failure beside it.
      _status = s.filterStatus;
      emit(s.copyWith(actionError: _message(e)));
    }
  }

  /// Runs one queue transition for [entry]; swaps the row with the entry
  /// the backend returns. Failures keep the row and surface [actionError].
  Future<void> transition(PanelWaitlistEntry entry, String action) async {
    final s = state;
    if (s is! WaitlistPanelLoaded) return;
    emit(s.copyWith(actionId: entry.id, clearError: true));
    try {
      final updated = await _repo.transition(
        restaurantId: restaurantId,
        id: entry.id,
        action: action,
      );
      if (isClosed) return;
      final entries = [
        for (final e in s.entries) if (e.id == entry.id) updated else e,
      ];
      _publishBadge(entries);
      emit(s.copyWith(entries: entries, clearAction: true));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Adds a walk-in to the queue and refreshes it, so the new entry shows
  /// up in the list behind the sheet.
  ///
  /// Returns `true` when the backend accepted the entry. A failure keeps
  /// the queue on screen and surfaces [WaitlistPanelLoaded.actionError]
  /// beside it.
  Future<bool> addWalkIn({
    required int guestsCount,
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    if (isClosed) return false;
    final s = state;
    if (s is WaitlistPanelLoaded) emit(s.copyWith(clearError: true));
    try {
      await _repo.createWaitlistEntry(
        restaurantId: restaurantId,
        guestsCount: guestsCount,
        name: name,
        phone: phone,
        email: email,
        specialRequests: notes,
      );
      if (isClosed) return true;
      // The queue is re-read so the new entry lands in the list (and in the
      // shell badge) instead of being spliced in by hand.
      await load();
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is WaitlistPanelLoaded) {
        emit(current.copyWith(actionError: _message(e)));
      } else {
        emit(WaitlistPanelError(_message(e)));
      }
      return false;
    }
  }

  void _publishBadge(List<PanelWaitlistEntry> entries) {
    waitlistBadgeCount.value = entries
        .where((e) => e.status == 'waiting' || e.status == 'notified')
        .length;
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
