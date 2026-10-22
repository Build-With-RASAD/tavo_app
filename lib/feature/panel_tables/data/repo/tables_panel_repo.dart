// lib/feature/panel_tables/data/repo/tables_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';

import '../model/table_models.dart';

class TablesPanelRepo {
  TablesPanelRepo({required this._api});
  final ApiService _api;

  /// The tables services return bare arrays (not pages): accept a List
  /// payload directly, else fall back to the nested page.
  List<Map<String, dynamic>> _rows(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    final (items: rows, pagination: _) = panelUnwrapList(payload);
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<PanelTableType>> getTableTypes(String restaurantId) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/tables?restaurantId=$restaurantId',
      );
      return _rows(
        panelPayload(res.data),
      ).map(PanelTableType.fromJson).toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<List<PanelPhysicalTable>> getPhysicalTables(
    String restaurantId,
    String tableTypeId,
  ) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/tables/$tableTypeId/physical?restaurantId=$restaurantId',
      );
      return _rows(
        panelPayload(res.data),
      ).map(PanelPhysicalTable.fromJson).toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// PUT {panelBase}/floor-plan (Task 4) → {updated:n}.
  Future<int> saveFloorPlan(
    String restaurantId,
    List<({String id, double? x, double? y})> positions,
  ) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/floor-plan?restaurantId=$restaurantId',
        data: {
          'tables': [
            for (final p in positions) {'_id': p.id, 'x': p.x, 'y': p.y},
          ],
        },
      );
      final payload = panelPayload(res.data);
      if (payload is Map<String, dynamic>) {
        return (payload['updated'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelPhysicalTable> updatePhysicalTableStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    try {
      final res = await _api.patch(
        '${ApiConstants.panelBase}/physical-tables/$id/status?restaurantId=$restaurantId',
        data: {'status': status},
      );
      return PanelPhysicalTable.fromJson(
        panelPayload(res.data) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// POST {panelBase}/tables/:tableTypeId/physical → the created table (201).
  Future<PanelPhysicalTable> createPhysicalTable({
    required String restaurantId,
    required String tableTypeId,
    required String code,
    required int seats,
    String? zone,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/tables/$tableTypeId/physical?restaurantId=$restaurantId',
        data: {
          'code': code,
          'seats': seats,
          if (zone != null) 'zone': zone,
        },
      );
      return PanelPhysicalTable.fromJson(
        panelPayload(res.data) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// PUT {panelBase}/physical-tables/:id — sends only the provided fields;
  /// [clearZone] sends an explicit `zone: null` (backend treats it as clear).
  /// Server-side 409s (duplicate code) surface through [parseDioError].
  Future<PanelPhysicalTable> updatePhysicalTable({
    required String restaurantId,
    required String id,
    String? code,
    int? seats,
    String? zone,
    bool clearZone = false,
  }) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/physical-tables/$id?restaurantId=$restaurantId',
        data: {
          if (code != null) 'code': code,
          if (seats != null) 'seats': seats,
          if (clearZone)
            'zone': null
          else if (zone != null)
            'zone': zone,
        },
      );
      return PanelPhysicalTable.fromJson(
        panelPayload(res.data) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// DELETE {panelBase}/physical-tables/:id → whether the backend deleted it.
  /// 409 (open order / active reservation) surfaces as a parsed error.
  Future<bool> deletePhysicalTable({
    required String restaurantId,
    required String id,
  }) async {
    try {
      final res = await _api.delete(
        '${ApiConstants.panelBase}/physical-tables/$id?restaurantId=$restaurantId',
      );
      final payload = panelPayload(res.data);
      if (payload is Map<String, dynamic>) {
        return payload['deleted'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
