// lib/feature/panel_dashboard/ui/logic/dashboard_extras_state.dart
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';

/// Rich-dashboard lifecycle: [DashboardExtrasInitial] →
/// [DashboardExtrasLoading] → [DashboardExtrasLoaded] on success or
/// [DashboardExtrasError] (plain message) on failure.
abstract class DashboardExtrasState {
  const DashboardExtrasState();
}

class DashboardExtrasInitial extends DashboardExtrasState {
  const DashboardExtrasInitial();
}

class DashboardExtrasLoading extends DashboardExtrasState {
  const DashboardExtrasLoading();
}

class DashboardExtrasLoaded extends DashboardExtrasState {
  const DashboardExtrasLoaded({
    required this.tables,
    required this.occupiedIds,
    required this.waitlist,
    required this.waitlistTotal,
    required this.ordersByStatus,
    this.actionError,
  });

  /// All physical tables across types (physical `status` never rewritten).
  final List<PanelPhysicalTable> tables;

  /// Table ids with an open order (status ∉ {served, cancelled}) — the
  /// binding occupied rule, computed client-side in the cubit.
  final Set<String> occupiedIds;

  /// First waitlist page (limit 5) and the endpoint's pagination total.
  final List<PanelWaitlistEntry> waitlist;
  final int waitlistTotal;

  /// Open + terminal order counts by status for the summary chips.
  final Map<String, int> ordersByStatus;

  /// Transient walk-in failure beside the loaded content (never a full error).
  final String? actionError;

  DashboardExtrasLoaded copyWith({
    List<PanelPhysicalTable>? tables,
    Set<String>? occupiedIds,
    List<PanelWaitlistEntry>? waitlist,
    int? waitlistTotal,
    Map<String, int>? ordersByStatus,
    String? actionError,
    bool clearError = false,
  }) {
    return DashboardExtrasLoaded(
      tables: tables ?? this.tables,
      occupiedIds: occupiedIds ?? this.occupiedIds,
      waitlist: waitlist ?? this.waitlist,
      waitlistTotal: waitlistTotal ?? this.waitlistTotal,
      ordersByStatus: ordersByStatus ?? this.ordersByStatus,
      actionError: clearError ? null : actionError ?? this.actionError,
    );
  }
}

class DashboardExtrasError extends DashboardExtrasState {
  const DashboardExtrasError(this.message);

  final String message;
}
