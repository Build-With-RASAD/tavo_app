// lib/feature/panel_menu/data/repo/menu_panel_repo.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';

import '../model/menu_models.dart';

/// Staff-side menu API: categories (with real item counts), paged/searchable
/// items, item CRUD with specifications, status toggles and item photos.
///
/// Every panel call carries `?restaurantId=` (without it the backend silently
/// falls back to the FIRST venue). Error style mirrors
/// [RestaurantPanelRepo] (plain-string errors via [parseDioError]).
class MenuPanelRepo {
  MenuPanelRepo({required this._api});
  final ApiService _api;

  /// Every panel call carries ?restaurantId= (global constraint 6).
  String _base(String restaurantId) =>
      '${ApiConstants.panelBase}/menu?restaurantId=$restaurantId';

  Future<List<PanelMenuCategory>> getCategories(String restaurantId) async {
    try {
      final res = await _api.get(
          '${ApiConstants.panelBase}/menu-categories?restaurantId=$restaurantId');
      final payload = panelPayload(res.data);
      final (items: rows, pagination: _) = panelUnwrapList(payload);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PanelMenuCategory.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// One page of items. `categoryId`, `status` and `search` are **server**
  /// filters, so page N of a category is really that category's page N.
  Future<({List<PanelMenuItem> items, int page, int pages, int total})>
      getItems(
    String restaurantId, {
    int page = 1,
    int limit = menuPageSize,
    String? categoryId,
    String? status,
    String? search,
  }) async {
    try {
      final q = StringBuffer(_base(restaurantId))
        ..write('&page=$page&limit=$limit');
      if (categoryId != null && categoryId.isNotEmpty) {
        q.write('&categoryId=$categoryId');
      }
      if (status != null) q.write('&status=$status');
      final term = search?.trim() ?? '';
      if (term.isNotEmpty) {
        q.write('&search=${Uri.encodeQueryComponent(term)}');
      }
      final res = await _api.get(q.toString());
      final payload = panelPayload(res.data);
      final (items: rows, pagination: pagination) = panelUnwrapList(payload);
      final items = rows
          .whereType<Map<String, dynamic>>()
          .map(PanelMenuItem.fromJson)
          .toList();
      return (
        items: items,
        page: (pagination?['page'] as num?)?.toInt() ?? page,
        pages: (pagination?['pages'] as num?)?.toInt() ?? 1,
        total: (pagination?['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelMenuItem> createItem({
    required String restaurantId,
    required PanelMenuItemPayload payload,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/menu?restaurantId=$restaurantId',
        data: payload.toJson(),
      );
      return _itemOf(res.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelMenuItem> updateItem({
    required String restaurantId,
    required String id,
    required PanelMenuItemPayload payload,
  }) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/menu/$id?restaurantId=$restaurantId',
        data: payload.toJson(),
      );
      return _itemOf(res.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelMenuItem> toggleStatus(String id, {String? restaurantId}) async {
    try {
      final res = await _api.patch(
          '${ApiConstants.panelBase}/menu/$id/status?restaurantId=$restaurantId');
      return _itemOf(res.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<void> deleteItem(String id, {String? restaurantId}) async {
    try {
      await _api.delete(
          '${ApiConstants.panelBase}/menu/$id?restaurantId=$restaurantId');
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelMenuCategory> createCategory({
    required String restaurantId,
    required String arName,
    required String enName,
  }) async {
    try {
      final res = await _api.post(
          '${ApiConstants.panelBase}/menu-categories?restaurantId=$restaurantId',
          data: {
            'ar': {'name': arName},
            'en': {'name': enName},
          });
      final payload = panelPayload(res.data);
      if (payload is Map) {
        return PanelMenuCategory.fromJson(
            Map<String, dynamic>.from(payload));
      }
      throw 'Empty response';
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// Renames a category. Missing before this: a typo in a category name was
  /// permanent unless you deleted and rebuilt the whole thing.
  Future<PanelMenuCategory> updateCategory({
    required String restaurantId,
    required String id,
    required String arName,
    required String enName,
  }) async {
    try {
      final res = await _api.put(
          '${ApiConstants.panelBase}/menu-categories/$id?restaurantId=$restaurantId',
          data: {
            'ar': {'name': arName},
            'en': {'name': enName},
          });
      final payload = panelPayload(res.data);
      if (payload is Map) {
        return PanelMenuCategory.fromJson(
            Map<String, dynamic>.from(payload));
      }
      throw 'Empty response';
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// 400 when the category still holds items (the server refuses to orphan
  /// them); the sheet disables the action first, this is the backstop.
  Future<void> deleteCategory(String id, {String? restaurantId}) async {
    try {
      await _api.delete(
          '${ApiConstants.panelBase}/menu-categories/$id?restaurantId=$restaurantId');
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `POST {panelBase}/menu/:id/image` — multipart field `image`, 200
  /// `{success, data:<updated item>}` (Task 10 contract, decision 11).
  Future<PanelMenuItem> uploadItemImage({
    required String restaurantId,
    required String id,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/menu/$id/image?restaurantId=$restaurantId',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
      return _itemOf(res.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `DELETE {panelBase}/menu/:id/image` — clears `image` on the item.
  Future<PanelMenuItem> removeItemImage({
    required String restaurantId,
    required String id,
  }) async {
    try {
      final res = await _api.delete(
          '${ApiConstants.panelBase}/menu/$id/image?restaurantId=$restaurantId');
      return _itemOf(res.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  PanelMenuItem _itemOf(dynamic data) {
    final payload = panelPayload(data);
    if (payload is Map) {
      return PanelMenuItem.fromJson(Map<String, dynamic>.from(payload));
    }
    throw 'Empty response';
  }
}

/// One page of the panel menu. 24 fits two full rows of the 2-column grid on
/// a phone without a scroll that ends mid-row.
const int menuPageSize = 24;
