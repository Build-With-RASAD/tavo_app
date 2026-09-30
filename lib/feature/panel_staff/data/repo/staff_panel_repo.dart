// lib/feature/panel_staff/data/repo/staff_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/staff_models.dart';

class StaffPanelRepo {
  StaffPanelRepo({required ApiService api}) : _api = api;
  final ApiService _api;

  String _q(String restaurantId) => '?restaurantId=$restaurantId';

  Future<List<PanelStaffMember>> getStaff(String restaurantId) async {
    try {
      final res = await _api
          .get('${ApiConstants.panelBase}/staff${_q(restaurantId)}');
      final payload = panelPayload(res.data);
      final rows =
          payload is List ? payload : panelUnwrapList(payload).items;
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PanelStaffMember.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelStaffMember> addStaff(
      {required String restaurantId,
      required String phone,
      required String name,
      required String role,
      required List<String> permissions}) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/staff${_q(restaurantId)}',
        data: {'phone': phone, 'name': name, 'role': role, 'permissions': permissions},
      );
      return PanelStaffMember.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelStaffMember> updateStaff(
      {required String restaurantId,
      required String id,
      String? role,
      List<String>? permissions,
      String? status}) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/staff/$id${_q(restaurantId)}',
        data: {
          if (role != null) 'role': role,
          if (permissions != null) 'permissions': permissions,
          if (status != null) 'status': status,
        },
      );
      return PanelStaffMember.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<void> deleteStaff(
      {required String restaurantId, required String id}) async {
    try {
      await _api.delete(
          '${ApiConstants.panelBase}/staff/$id${_q(restaurantId)}');
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
