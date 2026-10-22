// lib/feature/panel_customers/data/repo/customers_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/customer_models.dart';

class CustomersPanelRepo {
  CustomersPanelRepo({required this._api});
  final ApiService _api;

  Future<({List<PanelCustomer> customers, int page, int pages, int total})>
      getCustomers(String restaurantId, {int page = 1, String? search}) async {
    try {
      final q = StringBuffer(
          '${ApiConstants.panelBase}/customers?restaurantId=$restaurantId&page=$page&limit=20');
      if (search != null && search.isNotEmpty) {
        q.write('&search=${Uri.encodeQueryComponent(search)}');
      }
      final res = await _api.get(q.toString());
      final payload = panelPayload(res.data);
      final (items: rows, pagination: pagination) = panelUnwrapList(payload);
      return (
        customers: rows
            .whereType<Map<String, dynamic>>()
            .map(PanelCustomer.fromJson)
            .toList(),
        page: (pagination?['page'] as num?)?.toInt() ?? page,
        pages: (pagination?['pages'] as num?)?.toInt() ?? 1,
        total: (pagination?['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// Guest keys are phone strings — always URI-encoded.
  Future<PanelCustomerDetail> getCustomerDetail(
      String restaurantId, String key) async {
    try {
      final res = await _api.get(
          '${ApiConstants.panelBase}/customers/${Uri.encodeComponent(key)}?restaurantId=$restaurantId');
      return PanelCustomerDetail.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
