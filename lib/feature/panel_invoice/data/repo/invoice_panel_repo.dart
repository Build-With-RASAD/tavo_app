// lib/feature/panel_invoice/data/repo/invoice_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';

import '../model/invoice_models.dart';

/// Staff-side ZATCA invoice (Task 25 backend).
///
/// Mirrors [RestaurantPanelRepo]'s error style (plain-string errors).
/// [restaurantId] is mandatory like every other panel call: the backend
/// silently substitutes the FIRST venue when it is missing (cross-venue
/// wrong-target risk on the invoice action).
class InvoicePanelRepo {
  InvoicePanelRepo(this._api);

  final ApiService _api;

  /// `GET /restaurant-owner/orders/:id/invoice?restaurantId=…`.
  Future<PanelInvoice> getInvoice(String orderId, String restaurantId) async {
    try {
      final response = await _api.get(
        '${ApiConstants.panelBase}/orders/$orderId/invoice',
        queryParameters: {'restaurantId': restaurantId},
      );
      final payload = panelPayload(response.data);
      if (payload is Map) {
        return PanelInvoice.fromJson(Map<String, dynamic>.from(payload));
      }
      throw 'Empty response';
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }
}
