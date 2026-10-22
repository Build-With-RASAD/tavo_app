// lib/feature/panel_dashboard/data/repo/dashboard_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';

/// One panel order reduced to the occupancy/summary fields the dashboard
/// extras need. The full card shape stays in [PanelOrder]; parsing raw here
/// keeps this task's `tableId` read additive (no Task 12 file touched).
class DashboardOpenOrder {
  const DashboardOpenOrder({
    required this.id,
    required this.orderStatus,
    required this.tableId,
  });

  final String id;
  final String orderStatus;
  final String tableId;

  /// Occupied rule (binding): open ⟺ status ∉ {served, cancelled}.
  /// Computed client-side; the physical `status` is never rewritten.
  bool get isOpen => orderStatus != 'served' && orderStatus != 'cancelled';

  factory DashboardOpenOrder.fromJson(Map<String, dynamic> json) {
    final table = json['tableId'];
    return DashboardOpenOrder(
      id: (json['_id'] ?? json['id'])?.toString() ?? '',
      orderStatus: json['orderStatus']?.toString() ?? '',
      tableId:
          table is Map ? table['_id']?.toString() ?? '' : table?.toString() ?? '',
    );
  }
}

/// Rich-dashboard reads: floor tables across types (Task 4 shapes), a
/// waitlist preview (Task 5 endpoint), and open orders (Task 12 shape).
/// Errors surface as plain strings like every other panel repo.
class DashboardPanelRepo {
  DashboardPanelRepo({required this._api});
  final ApiService _api;

  /// Every physical table across all types: `GET /tables` for the type ids,
  /// then `GET /tables/:id/physical` per type (Task 4 endpoint shapes).
  Future<List<PanelPhysicalTable>> getFloorTables(
      String restaurantId) async {
    try {
      final typesRes = await _api.get(
        '${ApiConstants.panelBase}/tables?restaurantId=$restaurantId',
      );
      final payload = panelPayload(typesRes.data);
      final rows = payload is List
          ? payload.whereType<Map<String, dynamic>>().toList()
          : panelUnwrapList(payload).items.whereType<Map<String, dynamic>>().toList();
      final typeIds = rows
          .map((t) => t['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final pages = await Future.wait(typeIds.map((typeId) => _api.get(
            '${ApiConstants.panelBase}/tables/$typeId/physical?restaurantId=$restaurantId',
          )));
      return [
        for (final res in pages)
          ...panelUnwrapList(panelPayload(res.data))
              .items
              .whereType<Map<String, dynamic>>()
              .map(PanelPhysicalTable.fromJson),
      ];
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `GET /waitlist?page=1&limit=5`: the first FCFS page plus the endpoint's
  /// pagination total. The shell badge stays owned by the waitlist tab
  /// (`waitlistBadgeCount` untouched here).
  Future<({List<PanelWaitlistEntry> entries, int total})> getWaitlistPreview(
      String restaurantId) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/waitlist?restaurantId=$restaurantId&page=1&limit=5',
      );
      final (items: rows, pagination: pagination) =
          panelUnwrapList(panelPayload(res.data));
      return (
        entries: rows
            .whereType<Map<String, dynamic>>()
            .map(PanelWaitlistEntry.fromJson)
            .toList(),
        total: (pagination?['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `GET /orders?limit=100` (Task 12 shape, flat or nested envelope);
  /// occupancy filtering happens client-side in the cubit.
  Future<List<DashboardOpenOrder>> getOpenOrders(
      String restaurantId) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/orders?restaurantId=$restaurantId&page=1&limit=100',
      );
      final (items: rows, pagination: _) =
          panelUnwrapList(panelPayload(res.data));
      return rows
          .whereType<Map<String, dynamic>>()
          .map(DashboardOpenOrder.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `POST /waitlist` (Task 26 micro-endpoint): staff walk-in creation.
  /// Returns the created entry (`status: waiting`, server-issued ticket).
  Future<PanelWaitlistEntry> createWaitlistEntry({
    required String restaurantId,
    required int guestsCount,
    required String name,
    required String phone,
    String? email,
    String? specialRequests,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/waitlist?restaurantId=$restaurantId',
        data: {
          'guestsCount': guestsCount,
          'customer': {
            'name': name,
            'phone': phone,
            if (email != null && email.isNotEmpty) 'email': email,
          },
          if (specialRequests != null && specialRequests.isNotEmpty)
            'specialRequests': specialRequests,
        },
      );
      final payload = panelPayload(res.data);
      // 201 envelope is {success, data: {entry}} — accept the bare entry too.
      final map =
          payload is Map<String, dynamic> ? payload : <String, dynamic>{};
      final entryJson = map['entry'] is Map<String, dynamic>
          ? map['entry'] as Map<String, dynamic>
          : map;
      return PanelWaitlistEntry.fromJson(entryJson);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
