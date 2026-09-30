// ui/logic/panel_menu_state.dart
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
    this.filterStatus = 'all',
  });

  final List<PanelMenuCategory> categories;
  final List<PanelMenuItem> items;
  final int page;
  final int pages;
  final int total;
  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the list on screen
  final String? selectedCategoryId;
  final String filterStatus; // 'all' | 'active' | 'inactive' — status chips

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
      );
}

class PanelMenuError extends PanelMenuState {
  const PanelMenuError(this.message);
  final String message;
}
