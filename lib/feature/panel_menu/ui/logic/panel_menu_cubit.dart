// ui/logic/panel_menu_cubit.dart
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/menu_models.dart';
import '../../data/repo/menu_panel_repo.dart';

part 'panel_menu_state.dart';

/// Staff panel's menu list: categories, server-side status filter,
/// client-side category filter, page navigation and per-row mutations.
///
/// Error style mirrors `OrdersCubit` (plain strings): `load` failures emit
/// [PanelMenuError]; mutation failures keep the loaded list and surface a
/// transient [PanelMenuLoaded.actionError] beside it.
class PanelMenuCubit extends Cubit<PanelMenuState> {
  PanelMenuCubit(
    this._repo, {
    required this.restaurantId,
    required this._canManage,
  }) : super(const PanelMenuInitial());

  final MenuPanelRepo _repo;
  final String restaurantId;
  final bool Function() _canManage;

  bool get canManage => _canManage();

  Future<void> load() async {
    if (isClosed) return;
    emit(const PanelMenuLoading());
    try {
      final categories = await _repo.getCategories(restaurantId);
      final page = await _repo.getItems(restaurantId);
      if (isClosed) return;
      emit(PanelMenuLoaded(
        categories: categories,
        items: page.items,
        page: page.page,
        pages: page.pages,
        total: page.total,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(PanelMenuError(_message(e)));
    }
  }

  Future<void> setCategory(String? categoryId) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(
      clearCategory: categoryId == null,
      selectedCategoryId: categoryId,
      clearError: true,
    ));
    await _reload();
  }

  Future<void> goToPage(int page) async {
    final s = state;
    if (s is! PanelMenuLoaded || page < 1 || page > s.pages) return;
    await _reload(page: page);
  }

  /// Status chips: flips the server-side `&status=` filter and refetches
  /// from page 1 (`'all'` = no filter param).
  Future<void> setStatus(String status) async {
    final s = state;
    if (s is! PanelMenuLoaded || s.filterStatus == status) return;
    emit(s.copyWith(filterStatus: status, clearError: true));
    await _reload(page: 1);
  }

  Future<void> _reload({int? page}) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    try {
      final out = await _repo.getItems(
        restaurantId,
        page: page ?? s.page,
        categoryId: s.selectedCategoryId,
        status: s.filterStatus == 'all' ? null : s.filterStatus,
      );
      if (isClosed) return;
      emit(s.copyWith(
        items: out.items,
        page: out.page,
        pages: out.pages,
        total: out.total,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> toggleStatus(PanelMenuItem item) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(actionId: item.id, clearError: true));
    try {
      await _repo.toggleStatus(item.id, restaurantId: restaurantId);
      if (isClosed) return;
      final items = [
        for (final i in s.items)
          if (i.id == item.id)
            PanelMenuItem(
              id: i.id,
              categoryId: i.categoryId,
              arName: i.arName,
              enName: i.enName,
              price: i.price,
              active: !i.active,
              imageUrl: i.imageUrl,
              description: i.description,
            )
          else
            i,
      ];
      emit(s.copyWith(items: items, clearAction: true));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> deleteItem(PanelMenuItem item) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(actionId: item.id, clearError: true));
    try {
      await _repo.deleteItem(item.id, restaurantId: restaurantId);
      if (isClosed) return;
      emit(s.copyWith(
        items: s.items.where((i) => i.id != item.id).toList(),
        total: (s.total - 1).clamp(0, 1 << 31),
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> createCategory(
      {required String arName, required String enName}) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    try {
      final c = await _repo.createCategory(
          restaurantId: restaurantId, arName: arName, enName: enName);
      if (isClosed) return;
      emit(s.copyWith(categories: [...s.categories, c], clearError: true));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e)));
    }
  }

  Future<void> deleteCategory(PanelMenuCategory category) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(actionId: category.id, clearError: true));
    try {
      await _repo.deleteCategory(category.id, restaurantId: restaurantId);
      if (isClosed) return;
      emit(s.copyWith(
        categories: s.categories.where((c) => c.id != category.id).toList(),
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> saveItem({
    String? id,
    required String categoryId,
    required String arName,
    required String enName,
    required double price,
    String? description,
  }) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    try {
      final saved = id == null
          ? await _repo.createItem(
              restaurantId: restaurantId,
              categoryId: categoryId,
              arName: arName,
              enName: enName,
              price: price,
              description: description)
          : await _repo.updateItem(
              restaurantId: restaurantId,
              id: id,
              categoryId: categoryId,
              arName: arName,
              enName: enName,
              price: price,
              description: description);
      if (isClosed) return;
      final items = id == null
          ? [...s.items, saved]
          : [
              for (final i in s.items)
                if (i.id == id) saved else i,
            ];
      emit(s.copyWith(items: items, clearError: true));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e)));
    }
  }

  /// Photo upload/remove (multipart, Task 10 endpoint): swaps the row's
  /// `imageUrl` with the item the backend returns; failures keep the list.
  Future<void> uploadImage(String id, Uint8List bytes, String filename) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated = await _repo.uploadItemImage(
        restaurantId: restaurantId,
        id: id,
        bytes: bytes,
        filename: filename,
      );
      if (isClosed) return;
      emit(s.copyWith(
        items: [for (final i in s.items) if (i.id == id) updated else i],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> removeImage(String id) async {
    final s = state;
    if (s is! PanelMenuLoaded) return;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated =
          await _repo.removeItemImage(restaurantId: restaurantId, id: id);
      if (isClosed) return;
      emit(s.copyWith(
        items: [for (final i in s.items) if (i.id == id) updated else i],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
