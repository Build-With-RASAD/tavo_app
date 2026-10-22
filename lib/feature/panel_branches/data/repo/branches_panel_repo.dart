// lib/feature/panel_branches/data/repo/branches_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/branch_models.dart';

class BranchesPanelRepo {
  BranchesPanelRepo({required this._api});
  final ApiService _api;

  String _q(String restaurantId) => '?restaurantId=$restaurantId';

  /// Task 7 GET is a FLAT list: accept a List payload or a nested page.
  Future<List<PanelBranch>> getBranches(String restaurantId) async {
    try {
      final res = await _api
          .get('${ApiConstants.panelBase}/branches${_q(restaurantId)}');
      final payload = panelPayload(res.data);
      final rows =
          payload is List ? payload : panelUnwrapList(payload).items;
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PanelBranch.fromJson)
          .toList();
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Map<String, dynamic> _body({
    String? arName,
    String? enName,
    String? address,
    String? city,
    String? region,
    List<String>? phones,
    String? email,
    String? whatsapp,
    double? latitude,
    double? longitude,
    Map<String, Map<String, dynamic>>? workingHours,
    String? managerName,
    bool? isActive,
    bool? isMain,
  }) =>
      {
        if (arName != null || enName != null || address != null || city != null || region != null)
          ...{
            if (arName != null || address != null || city != null || region != null)
              'ar': {
                if (arName != null) 'name': arName,
                if (address != null) 'address': address,
                if (city != null) 'city': city,
                if (region != null) 'region': region,
              },
            if (enName != null || address != null || city != null || region != null)
              'en': {
                if (enName != null) 'name': enName,
                if (address != null) 'address': address,
                if (city != null) 'city': city,
                if (region != null) 'region': region,
              },
          },
        if (phones != null) 'phones': phones,
        if (email != null) 'email': email,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (latitude != null && longitude != null)
          'location': {
            'coordinates': [longitude, latitude]
          },
        if (workingHours != null) 'workingHours': workingHours,
        if (managerName != null) 'manager': {'name': managerName},
        if (isActive != null) 'isActive': isActive,
        if (isMain != null) 'isMain': isMain,
      };

  Future<PanelBranch> createBranch({
    required String restaurantId,
    required String arName,
    required String enName,
    required String address,
    required String city,
    required String region,
    required List<String> phones,
    String? email,
    String? whatsapp,
    double? latitude,
    double? longitude,
    required Map<String, Map<String, dynamic>> workingHours,
    String? managerName,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/branches${_q(restaurantId)}',
        data: _body(
          arName: arName, enName: enName, address: address, city: city,
          region: region, phones: phones, email: email, whatsapp: whatsapp,
          latitude: latitude, longitude: longitude, workingHours: workingHours,
          managerName: managerName,
        ),
      );
      return PanelBranch.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelBranch> updateBranch({
    required String restaurantId,
    required String id,
    String? arName,
    String? enName,
    String? address,
    String? city,
    String? region,
    List<String>? phones,
    String? email,
    String? whatsapp,
    double? latitude,
    double? longitude,
    Map<String, Map<String, dynamic>>? workingHours,
    String? managerName,
    bool? isActive,
    bool? isMain,
  }) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/branches/$id${_q(restaurantId)}',
        data: _body(
          arName: arName, enName: enName, address: address, city: city,
          region: region, phones: phones, email: email, whatsapp: whatsapp,
          latitude: latitude, longitude: longitude, workingHours: workingHours,
          managerName: managerName, isActive: isActive, isMain: isMain,
        ),
      );
      return PanelBranch.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelBranch> deleteBranch(
      {required String restaurantId, required String id}) async {
    try {
      final res = await _api.delete(
          '${ApiConstants.panelBase}/branches/$id${_q(restaurantId)}');
      return PanelBranch.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
