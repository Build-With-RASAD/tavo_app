// lib/feature/panel_menu/ui/logic/panel_menu_state.dart
part of 'panel_menu_cubit.dart';

sealed class PanelMenuState {
  const PanelMenuState();
}

class PanelMenuInitial extends PanelMenuState {
  const PanelMenuInitial();
}

class PanelMenuLoading extends PanelMenuState {
  const PanelMenuLoading();
}

class PanelMenuLoaded extends PanelMenuState {
  const PanelMenuLoaded({
    required this.categories,
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
    this.actionId,
    this.actionError,
    this.selectedCategoryId,
    this.filterStatus = PanelMenuStatusFilter.all,
    this.query = '',
    this.refreshing = false,
    this.saving = false,
    this.activeCount = 0,
    this.inactiveCount = 0,
  });

  final List<PanelMenuCategory> categories;
  final List<PanelMenuItem> items;
  final int page;
  final int pages;
  final int total;

  /// Per-row spinner target (toggle, photo upload, delete).
  final String? actionId;

  /// Transient mutation failure; the list stays on screen.
  final String? actionError;

  final String? selectedCategoryId;

  /// `all | active | inactive` — a server-side filter.
  final String filterStatus;

  /// Free-text search, also server-side so pagination stays honest.
  final String query;

  /// A pull-to-refresh / filter reload is in flight (keeps the old rows).
  final bool refreshing;

  /// The editor sheet is saving.
  final bool saving;

  /// Server counts for the status chips (`limit=1` reads, scoped to the
  /// active category and search — never arithmetic over [items]).
  final int activeCount;
  final int inactiveCount;

  bool get hasFilters =>
      selectedCategoryId != null ||
      filterStatus != PanelMenuStatusFilter.all ||
      query.trim().isNotEmpty;

  /// Index (1-based) of the first row on this page, for "1–24 of 61".
  int get firstRow => total == 0 ? 0 : (page - 1) * menuPageSize + 1;

  /// Index of the last row on this page.
  int get lastRow => total == 0 ? 0 : firstRow + items.length - 1;

  PanelMenuCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  PanelMenuItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Category rail: every category with its real item count, "all" first.
  /// Both statuses together, so the number does not collapse to the filtered
  /// page total when a status chip is active.
  int get allCount => activeCount + inactiveCount;

  /// Count rendered on a status chip.
  int countFor(String status) => switch (status) {
        PanelMenuStatusFilter.active => activeCount,
        PanelMenuStatusFilter.inactive => inactiveCount,
        _ => allCount,
      };

  PanelMenuLoaded copyWith({
    List<PanelMenuCategory>? categories,
    List<PanelMenuItem>? items,
    int? page,
    int? pages,
    int? total,
    String? actionId,
    String? actionError,
    String? selectedCategoryId,
    String? filterStatus,
    String? query,
    bool? refreshing,
    bool? saving,
    int? activeCount,
    int? inactiveCount,
    bool clearAction = false,
    bool clearError = false,
    bool clearCategory = false,
  }) =>
      PanelMenuLoaded(
        categories: categories ?? this.categories,
        items: items ?? this.items,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        total: total ?? this.total,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
        // `selectedCategoryId: null` must clear the filter, so clearing is
        // an explicit flag rather than the nullable value itself.
        selectedCategoryId:
            clearCategory ? null : selectedCategoryId ?? this.selectedCategoryId,
        filterStatus: filterStatus ?? this.filterStatus,
        query: query ?? this.query,
        refreshing: refreshing ?? this.refreshing,
        saving: saving ?? this.saving,
        activeCount: activeCount ?? this.activeCount,
        inactiveCount: inactiveCount ?? this.inactiveCount,
      );
}

class PanelMenuError extends PanelMenuState {
  const PanelMenuError(this.message);
  final String message;
}

/// Status chips. Values match the `status` enum on the backend.
abstract final class PanelMenuStatusFilter {
  static const String all = 'all';
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const List<String> values = [all, active, inactive];
}
