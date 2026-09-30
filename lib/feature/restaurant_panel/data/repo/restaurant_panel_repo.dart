import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
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

  /// `PATCH /restaurant-owner/orders/:id/status?restaurantId=…` with `{status}`.
  ///
  /// [restaurantId] is mandatory like every other panel call: the backend
  /// silently substitutes the FIRST venue when it is missing (cross-venue
  /// wrong-target risk on the status action).
  Future<PanelOrder> updateOrderStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.panelOrderStatus(id),
        data: {'status': status},
        queryParameters: {'restaurantId': restaurantId},
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

  /// Panel reservations for one venue (Task 13 migration target).
  /// Nested envelope `{success, data:{data,pagination}}` via Task 1 helpers.
  Future<List<BookingModel>> getReservations(
    String restaurantId, {
    int limit = 100,
  }) async {
    try {
      final res = await _apiService.get(
        '${ApiConstants.panelBase}/reservations?restaurantId=$restaurantId&limit=$limit',
      );
      final payload = panelPayload(res.data);
      final result = panelUnwrapList(payload);
      return result.items
          .whereType<Map<String, dynamic>>()
          .map(BookingModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// Panel status transition: `PATCH {panelBase}/reservations/:id/<action>`.
  Future<BookingModel> updateReservationAction({
    required String restaurantId,
    required String id,
    required String action,
    String? reason,
  }) async {
    try {
      final res = await _apiService.patch(
        '${ApiConstants.panelBase}/reservations/$id/$action?restaurantId=$restaurantId',
        data: action == 'cancel'
            ? {'reason': reason ?? 'Cancelled by restaurant'}
            : null,
      );
      final data = res.data;
      if (data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] != null &&
          data['data'] is Map<String, dynamic>) {
        return BookingModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw (data is Map<String, dynamic> && data['message'] != null)
          ? data['message'].toString()
          : 'Failed to update reservation';
    } on DioException catch (e) {
      throw parseDioError(e);
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
