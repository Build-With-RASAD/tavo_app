// lib/feature/panel_contact/data/repo/contact_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/contact_models.dart';

class ContactPanelRepo {
  ContactPanelRepo({required this._api});
  final ApiService _api;

  String _q(String restaurantId) => '?restaurantId=$restaurantId';

  Future<PanelContact> getContact(String restaurantId) async {
    try {
      final res = await _api
          .get('${ApiConstants.panelBase}/contact${_q(restaurantId)}');
      return PanelContact.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  Future<PanelContact> updateContact({
    required String restaurantId,
    String? phone,
    String? email,
    String? whatsapp,
    Map<String, String>? socialLinks,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    try {
      final res = await _api.put(
        '${ApiConstants.panelBase}/contact${_q(restaurantId)}',
        data: {
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (whatsapp != null) 'whatsapp': whatsapp,
          if (socialLinks != null) 'socialLinks': socialLinks,
          if (descriptionAr != null || descriptionEn != null)
            'description': {
              if (descriptionAr != null) 'ar': descriptionAr,
              if (descriptionEn != null) 'en': descriptionEn,
            },
        },
      );
      return PanelContact.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
