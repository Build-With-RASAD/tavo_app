// lib/feature/panel_waitlist/data/repo/waitlist_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import '../model/waitlist_models.dart';

class WaitlistPanelRepo {
  WaitlistPanelRepo({required this._api});
  final ApiService _api;

  Future<({List<PanelWaitlistEntry> entries, int page, int pages, int total})>
      getWaitlist(String restaurantId, {int page = 1, String? status}) async {
    try {
      final q = StringBuffer(
          '${ApiConstants.panelBase}/waitlist?restaurantId=$restaurantId&page=$page&limit=20');
      if (status != null) q.write('&status=$status');
      final res = await _api.get(q.toString());
      final payload = panelPayload(res.data);
      final (items: rows, pagination: pagination) = panelUnwrapList(payload);
      return (
        entries: rows
            .whereType<Map<String, dynamic>>()
            .map(PanelWaitlistEntry.fromJson)
            .toList(),
        page: (pagination?['page'] as num?)?.toInt() ?? page,
        pages: (pagination?['pages'] as num?)?.toInt() ?? 1,
        total: (pagination?['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// `action` ∈ notify|confirm|no-show|cancel; the URL uses the Task 5
  /// hyphenated `no-show` path — callers pass it through unchanged.
  Future<PanelWaitlistEntry> transition(
      {required String restaurantId,
      required String id,
      required String action}) async {
    try {
      final res = await _api.patch(
        '${ApiConstants.panelBase}/waitlist/$id/$action?restaurantId=$restaurantId',
      );
      return PanelWaitlistEntry.fromJson(
          panelPayload(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
