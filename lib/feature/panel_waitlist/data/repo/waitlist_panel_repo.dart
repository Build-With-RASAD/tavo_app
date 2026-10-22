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

  /// `POST /waitlist` (Task 26 micro-endpoint): staff walk-in creation.
  /// Returns the created entry (`status: waiting`, server-issued ticket).
  ///
  /// It lived in the old dashboard repo until the Wave 2 dashboard rebuild
  /// deleted that file; the waitlist module owns it now.
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
