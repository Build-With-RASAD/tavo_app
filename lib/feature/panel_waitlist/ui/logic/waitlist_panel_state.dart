// lib/feature/panel_waitlist/ui/logic/waitlist_panel_state.dart
import '../../data/model/waitlist_models.dart';

sealed class WaitlistPanelState {
  const WaitlistPanelState();
}

class WaitlistPanelInitial extends WaitlistPanelState {
  const WaitlistPanelInitial();
}

class WaitlistPanelLoading extends WaitlistPanelState {
  const WaitlistPanelLoading();
}

class WaitlistPanelLoaded extends WaitlistPanelState {
  const WaitlistPanelLoaded({
    required this.entries,
    required this.page,
    required this.pages,
    required this.total,
    this.actionId,
    this.actionError,
    this.filterStatus,
  });

  final List<PanelWaitlistEntry> entries;
  final int page;
  final int pages;
  final int total;
  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the queue on screen
  final String? filterStatus; // null = all — the server-side `&status=` filter

  WaitlistPanelLoaded copyWith({
    List<PanelWaitlistEntry>? entries,
    int? page,
    int? pages,
    int? total,
    String? actionId,
    String? actionError,
    String? filterStatus,
    bool clearAction = false,
    bool clearError = false,
    bool clearFilter = false,
  }) =>
      WaitlistPanelLoaded(
        entries: entries ?? this.entries,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        total: total ?? this.total,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
        // `filterStatus: null` must clear the filter, so clearing is an
        // explicit flag rather than the nullable value itself.
        filterStatus:
            clearFilter ? null : filterStatus ?? this.filterStatus,
      );
}

class WaitlistPanelError extends WaitlistPanelState {
  const WaitlistPanelError(this.message);
  final String message;
}
