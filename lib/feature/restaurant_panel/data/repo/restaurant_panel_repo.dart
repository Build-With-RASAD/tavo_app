import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';

/// Staff-side API: dashboard stats, paginated orders and order status changes.
///
/// Mirrors [RestaurantAuthRepo]'s error style (plain-string errors) so cubits
/// and UI treat both flows identically. Panel paths are host-less and every
/// call carries `?restaurantId=` — without it the backend silently falls back
/// to the FIRST venue.
class RestaurantPanelRepo {
  final ApiService _apiService;

  RestaurantPanelRepo(this._apiService);

  /// `GET /restaurant-owner/dashboard?restaurantId=…`.
  Future<DashboardStats> getDashboard(String restaurantId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.panelDashboard,
        queryParameters: {'restaurantId': restaurantId},
      );
      final payload = _payloadOf(response.data);
      if (payload is Map) {
        return DashboardStats.fromJson(Map<String, dynamic>.from(payload));
      }
      throw 'Empty response';
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// `GET /restaurant-owner/orders?restaurantId=…&page=…&limit=…[&status=…]`.
  ///
  /// The backend returns two envelope shapes: a flat `{data: [...]}` list and
  /// a nested `{data: {data: [...], pagination: {...}}}` page — both are
  /// accepted; without pagination the result reads as a single page.
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.panelOrders,
        queryParameters: {
          'restaurantId': restaurantId,
          'page': page,
          'limit': limit,
          if (status != null) 'status': status,
        },
      );
      final (items: items, pagination: pagination) =
          _unwrapList(_payloadOf(response.data));
      final orders = items
          .map((e) =>
              PanelOrder.fromJson(_asMap(e) ?? const <String, dynamic>{}))
          .toList();
      return PagedResult<PanelOrder>(
        items: orders,
        page: _toIntOrNull(pagination?['page']) ?? 1,
        limit: _toIntOrNull(pagination?['limit']) ?? limit,
        total: _toIntOrNull(pagination?['total']) ?? orders.length,
        pages: _toIntOrNull(pagination?['pages']) ?? (orders.isEmpty ? 0 : 1),
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// `PATCH /restaurant-owner/orders/:id/status` with `{status}`.
  Future<PanelOrder> updateOrderStatus({
    required String id,
    required String status,
  }) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.panelOrderStatus(id),
        data: {'status': status},
      );
      final payload = _payloadOf(response.data);
      if (payload is Map) {
        return PanelOrder.fromJson(Map<String, dynamic>.from(payload));
      }
      throw 'Empty response';
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  /// Extracts `response.data['data']` — the payload every panel envelope wraps.
  dynamic _payloadOf(dynamic data) =>
      data is Map<String, dynamic> ? data['data'] : null;

  ({List<dynamic> items, Map<String, dynamic>? pagination})
      _unwrapList(dynamic payload) {
    if (payload is List) return (items: payload, pagination: null);
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return (
        items: payload['data'] as List,
        pagination: payload['pagination'] is Map<String, dynamic>
            ? payload['pagination'] as Map<String, dynamic>
            : null,
      );
    }
    throw 'Empty response';
  }

  Map<String, dynamic>? _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  int? _toIntOrNull(Object? value) =>
      value is num ? value.toInt() : int.tryParse('${value ?? ''}');
}
