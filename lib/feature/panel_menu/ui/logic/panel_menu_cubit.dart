// lib/feature/panel_menu/ui/logic/panel_menu_cubit.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/menu_models.dart';
import '../../data/repo/menu_panel_repo.dart';

part 'panel_menu_state.dart';

/// Staff panel's menu editor: categories with real counts, server-side
/// category / status / search filters, page navigation and per-row mutations.
///
/// Every filter is a **server** filter. That is the whole point of this cubit:
/// filtering the current page client-side made "Drinks" show an empty list
/// whenever its items happened to live on page 2.
///
/// The status chips' counts are server reads too (`limit=1`, one per status),
/// scoped to the active category and search — never arithmetic over the 24
/// rows currently on screen.
///
/// Error style mirrors `OrdersCubit` (plain strings): `load` failures emit
/// [PanelMenuError]; mutation failures keep the loaded list and surface a
/// transient [PanelMenuLoaded.actionError] beside it.
class PanelMenuCubit extends Cubit<PanelMenuState> {
  PanelMenuCubit(
    this._repo, {
    required this.restaurantId,
    required this.canManage,
    this.searchDebounce = const Duration(milliseconds: 320),
  }) : super(const PanelMenuInitial());

  final MenuPanelRepo _repo;
  final String restaurantId;

  /// Mirrors `requirePermission('manage_menu')`. Read on every build so a
  /// venue/permission change is reflected without rebuilding the cubit.
  final bool Function() canManage;

  /// How long typing settles before the search hits the server.
  final Duration searchDebounce;

  Timer? _searchTimer;

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }

  Future<void> load() async {
    if (isClosed) return;
    emit(const PanelMenuLoading());
    try {
      final categoriesFuture = _repo.getCategories(restaurantId);
      final pageFuture = _repo.getItems(restaurantId);
      final countsFuture = _readCounts(categoryId: null, search: '');
      final categories = await categoriesFuture;
      final page = await pageFuture;
      final counts = await countsFuture;
      if (isClosed) return;
      emit(PanelMenuLoaded(
        categories: categories,
        items: page.items,
        page: page.page,
        pages: page.pages,
        total: page.total,
        activeCount: counts.active,
        inactiveCount: counts.inactive,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(PanelMenuError(_message(e)));
    }
  }

  /// Keeps the current rows while re-reading the page (pull-to-refresh,
  /// filter changes). A failure surfaces inline instead of wiping the list.
  Future<void> refresh() async {
    final s = state;
    if (s is! PanelMenuLoaded || s.refreshing) return;
    emit(s.copyWith(refreshing: true, clearError: true));
    try {
      // Categories are re-read too: another device may have added a category
      // or changed an item's category since the last load.
      final categoriesFuture = _repo.getCategories(restaurantId);
      final pageFuture = _repo.getItems(
        restaurantId,
        page: s.page,
        categoryId: s.selectedCategoryId,
        status: _statusParam(s.filterStatus),
        search: s.query,
      );
      final countsFuture = _readCounts(
        categoryId: s.selectedCategoryId,
        search: s.query,
      );
      final categories = await categoriesFuture;
      final page = await pageFuture;
      final counts = await countsFuture;
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      emit(current.copyWith(
        categories: categories,
        items: page.items,
        page: page.page,
        pages: page.pages,
        total: page.total,
        activeCount: counts.active,
        inactiveCount: counts.inactive,
        refreshing: false,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      emit(current.copyWith(
        refreshing: false,
        clearAction: true,
        actionError: _message(e),
      ));
    }
  }

  Future<void> setCategory(String? categoryId) async {
    final s = state;
    if (s is! PanelMenuLoaded || s.selectedCategoryId == categoryId) return;
    emit(s.copyWith(
      clearCategory: categoryId == null,
      selectedCategoryId: categoryId,
      page: 1,
      clearError: true,
    ));
    await _reload(page: 1);
  }

  /// Debounced so typing does not fire one request per keystroke.
  void setQuery(String query) {
    final s = state;
    if (s is! PanelMenuLoaded || s.query == query) return;
    emit(s.copyWith(query: query, page: 1, clearError: true));
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      unawaited(_reload(page: 1));
    });
  }

  /// Applies the pending search immediately (keyboard "search" action).
  Future<void> submitSearch() async {
    _searchTimer?.cancel();
    final s = state;
    if (s is! PanelMenuLoaded) return;
    await _reload(page: 1);
  }

  Future<void> clearFilters() async {
    final s = state;
    if (s is! PanelMenuLoaded || !s.hasFilters) return;
    _searchTimer?.cancel();
    emit(s.copyWith(
      clearCategory: true,
      filterStatus: PanelMenuStatusFilter.all,
      query: '',
      page: 1,
      clearError: true,
    ));
    await _reload(page: 1);
  }

  Future<void> goToPage(int page) async {
    final s = state;
    if (s is! PanelMenuLoaded || page < 1 || page > s.pages) return;
    if (page == s.page) return;
    await _reload(page: page);
  }

  /// Status chips: flips the server-side `&status=` filter and refetches
  /// from page 1 (`'all'` = no filter param).
  Future<void> setStatus(String status) async {
    final s = state;
    if (s is! PanelMenuLoaded || s.filterStatus == status) return;
    _searchTimer?.cancel();
    emit(s.copyWith(filterStatus: status, page: 1, clearError: true));
    await _reload(page: 1);
  }

  Future<void> _reload({int? page}) async {
    final s = state;
    if (s is! PanelMenuLoaded || s.refreshing) return;
    emit(s.copyWith(refreshing: true, clearError: true));
    try {
      final pageFuture = _repo.getItems(
        restaurantId,
        page: page ?? s.page,
        categoryId: s.selectedCategoryId,
        status: _statusParam(s.filterStatus),
        search: s.query,
      );
      final countsFuture = _readCounts(
        categoryId: s.selectedCategoryId,
        search: s.query,
      );
      final pageResult = await pageFuture;
      final counts = await countsFuture;
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      emit(current.copyWith(
        items: pageResult.items,
        page: pageResult.page,
        pages: pageResult.pages,
        total: pageResult.total,
        activeCount: counts.active,
        inactiveCount: counts.inactive,
        refreshing: false,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      emit(current.copyWith(
        refreshing: false,
        clearAction: true,
        actionError: _message(e),
      ));
    }
  }

  /// One `limit=1` read per status. Both are scoped to the active category
  /// and search so the chips describe what the filter would show, not the
  /// page that happens to be loaded.
  Future<({int active, int inactive})> _readCounts({
    String? categoryId,
    required String search,
  }) async {
    final activeFuture = _repo.getItems(
      restaurantId,
      limit: 1,
      categoryId: categoryId,
      status: PanelMenuStatusFilter.active,
      search: search,
    );
    final inactiveFuture = _repo.getItems(
      restaurantId,
      limit: 1,
      categoryId: categoryId,
      status: PanelMenuStatusFilter.inactive,
      search: search,
    );
    final active = await activeFuture;
    final inactive = await inactiveFuture;
    return (active: active.total, inactive: inactive.total);
  }

  Future<bool> toggleStatus(PanelMenuItem item) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    emit(s.copyWith(actionId: item.id, clearError: true));
    try {
      final updated =
          await _repo.toggleStatus(item.id, restaurantId: restaurantId);
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(_replace(updated, clearAction: true));

      // Under a status filter the row no longer belongs on this page, and
      // when it was the last row the page itself disappears. A reload keeps
      // the list honest; without a filter the in-place swap is enough.
      if (current.filterStatus != PanelMenuStatusFilter.all) {
        await _reload();
      } else {
        await _reloadCounts();
      }
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e), clearAction: true));
      return false;
    }
  }

  Future<bool> deleteItem(PanelMenuItem item) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    emit(s.copyWith(actionId: item.id, clearError: true));
    try {
      await _repo.deleteItem(item.id, restaurantId: restaurantId);
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;

      final items = current.items.where((i) => i.id != item.id).toList();
      emit(current.copyWith(
        items: items,
        total: current.total > 0 ? current.total - 1 : 0,
        categories: _adjustCount(item.categoryId, -1, from: current.categories),
        clearAction: true,
      ));

      // Deleting the only row of page 3 must not leave an empty page.
      if (items.isEmpty && current.page > 1) {
        await _reload(page: current.page - 1);
      } else {
        await _reloadCounts();
      }
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e), clearAction: true));
      return false;
    }
  }

  /// Creates or updates one item. Returns whether the write landed so the
  /// editor sheet can stay open (and show the error) on failure.
  ///
  /// On success the page is re-read instead of patched locally: the server
  /// decides the sort order, the counts and whether the item still matches
  /// an active search or category filter.
  Future<bool> saveItem({
    String? id,
    required PanelMenuItemPayload payload,
  }) async {
    final s = state;
    if (s is! PanelMenuLoaded || s.saving) return false;
    emit(s.copyWith(saving: true, clearError: true));
    try {
      if (id == null) {
        await _repo.createItem(restaurantId: restaurantId, payload: payload);
      } else {
        await _repo.updateItem(
          restaurantId: restaurantId,
          id: id,
          payload: payload,
        );
      }
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(saving: false, clearError: true));

      if (id == null && current.page != 1) {
        // Newest first: the item the user just created lives on page 1.
        await _reload(page: 1);
      } else {
        await refresh();
      }
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(saving: false, actionError: _message(e)));
      return false;
    }
  }

  Future<bool> createCategory({
    required String arName,
    required String enName,
  }) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    try {
      final created = await _repo.createCategory(
        restaurantId: restaurantId,
        arName: arName,
        enName: enName,
      );
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(
        categories: [...current.categories, created],
        clearError: true,
      ));
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e)));
      return false;
    }
  }

  Future<bool> updateCategory(
    PanelMenuCategory category, {
    required String arName,
    required String enName,
  }) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    try {
      final updated = await _repo.updateCategory(
        restaurantId: restaurantId,
        id: category.id,
        arName: arName,
        enName: enName,
      );
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(
        categories: [
          for (final c in current.categories)
            if (c.id == category.id) updated else c,
        ],
        clearError: true,
      ));
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e)));
      return false;
    }
  }

  Future<bool> deleteCategory(PanelMenuCategory category) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;

    // The server refuses this too; checking first keeps the sheet open with
    // a reason instead of flashing a raw 400.
    if (category.itemCount > 0) {
      emit(s.copyWith(actionError: 'category_not_empty'));
      return false;
    }

    emit(s.copyWith(actionId: category.id, clearError: true));
    try {
      await _repo.deleteCategory(category.id, restaurantId: restaurantId);
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      final removingSelected = current.selectedCategoryId == category.id;
      emit(current.copyWith(
        categories:
            current.categories.where((c) => c.id != category.id).toList(),
        clearCategory: removingSelected,
        clearAction: true,
      ));
      if (removingSelected) await _reload(page: 1);
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e), clearAction: true));
      return false;
    }
  }

  /// Photo upload/remove (multipart): swaps the row's `imageUrl` with the
  /// item the backend returns; failures keep the list.
  Future<bool> uploadImage(String id, Uint8List bytes, String filename) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated = await _repo.uploadItemImage(
        restaurantId: restaurantId,
        id: id,
        bytes: bytes,
        filename: filename,
      );
      if (isClosed) return false;
      emit(_replace(updated, clearAction: true));
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e), clearAction: true));
      return false;
    }
  }

  Future<bool> removeImage(String id) async {
    final s = state;
    if (s is! PanelMenuLoaded) return false;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated =
          await _repo.removeItemImage(restaurantId: restaurantId, id: id);
      if (isClosed) return false;
      emit(_replace(updated, clearAction: true));
      return true;
    } catch (e) {
      if (isClosed) return false;
      final current = state;
      if (current is! PanelMenuLoaded) return false;
      emit(current.copyWith(actionError: _message(e), clearAction: true));
      return false;
    }
  }

  void clearActionError() {
    final s = state;
    if (s is PanelMenuLoaded && s.actionError != null) {
      emit(s.copyWith(clearError: true));
    }
  }

  /// Refreshes only the two status counts. Failures are swallowed: a chip
  /// number is not worth replacing a working list with an error banner.
  Future<void> _reloadCounts() async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    try {
      final counts =
          await _readCounts(categoryId: s.selectedCategoryId, search: s.query);
      if (isClosed) return;
      final current = state;
      if (current is! PanelMenuLoaded) return;
      emit(current.copyWith(
        activeCount: counts.active,
        inactiveCount: counts.inactive,
      ));
    } catch (_) {
      // Keep the previous counts.
    }
  }

  String? _statusParam(String filter) =>
      filter == PanelMenuStatusFilter.all ? null : filter;

  /// Replaces one item in place, preserving the current order.
  PanelMenuLoaded _replace(PanelMenuItem updated, {bool clearAction = false}) {
    final current = state as PanelMenuLoaded;
    return current.copyWith(
      items: [
        for (final item in current.items)
          if (item.id == updated.id) updated else item,
      ],
      clearAction: clearAction,
    );
  }

  List<PanelMenuCategory> _adjustCount(
    String categoryId,
    int delta, {
    List<PanelMenuCategory>? from,
  }) {
    final source = from ?? (state as PanelMenuLoaded).categories;
    return [
      for (final category in source)
        if (category.id == categoryId)
          PanelMenuCategory(
            id: category.id,
            arName: category.arName,
            enName: category.enName,
            itemCount: category.itemCount + delta < 0
                ? 0
                : category.itemCount + delta,
          )
        else
          category,
    ];
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
