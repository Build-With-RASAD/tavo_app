// lib/feature/panel_dashboard/data/repo/analytics_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';
import 'package:tavo/feature/panel_dashboard/data/model/analytics_models.dart';

/// The two analytics reads (spec §"New backend contracts"):
///
///   * `GET /analytics` — the HEAVY, range-scoped payload. It runs on a
///     range change and on pull-to-refresh, NEVER on the 20-second poll.
///   * `GET /analytics/live` — the cheap snapshot the poll reads.
///
/// **Every call carries `restaurantId`**: without it the backend silently
/// falls back to the FIRST venue, which would show another restaurant's
/// money on this screen.
///
/// `to` is the LAST DAY of the window (inclusive): the backend must treat it
/// as end-of-day, otherwise "today" reads zero.
class AnalyticsPanelRepo {
  AnalyticsPanelRepo({required this._api});

  final ApiService _api;

  /// The heavy, range-scoped payload.
  Future<DashboardAnalytics> getAnalytics({
    required String restaurantId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/analytics',
        queryParameters: {
          'restaurantId': restaurantId,
          'from': _isoDate(from),
          'to': _isoDate(to),
        },
      );
      final payload = panelPayload(res.data);
      return DashboardAnalytics.fromJson(panelAsMap(payload) ?? const {});
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// The cheap snapshot — safe to poll every 20 seconds.
  Future<LiveSnapshot> getLiveSnapshot(String restaurantId) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/analytics/live',
        queryParameters: {'restaurantId': restaurantId},
      );
      final payload = panelPayload(res.data);
      return LiveSnapshot.fromJson(panelAsMap(payload) ?? const {});
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// ISO calendar date (`yyyy-MM-dd`) — the format the validator parses.
  static String _isoDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);
}
