// lib/feature/panel_reviews/data/repo/reviews_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';

import '../model/experience_summary.dart';
import '../model/review_models.dart';

class ReviewsPanelRepo {
  ReviewsPanelRepo({required this._api});
  final ApiService _api;

  Future<({List<PanelReview> reviews, int page, int pages, int total})>
  getReviews(String restaurantId, {int page = 1, int? rating}) async {
    try {
      final q = StringBuffer(
        '${ApiConstants.panelBase}/reviews?restaurantId=$restaurantId&page=$page&limit=20',
      );
      if (rating != null) q.write('&rating=$rating');
      final res = await _api.get(q.toString());
      final payload = panelPayload(res.data);
      final (items: rows, pagination: pagination) = panelUnwrapList(payload);
      return (
        reviews: rows
            .whereType<Map<String, dynamic>>()
            .map(PanelReview.fromJson)
            .toList(),
        page: (pagination?['page'] as num?)?.toInt() ?? page,
        pages: (pagination?['pages'] as num?)?.toInt() ?? 1,
        total: (pagination?['total'] as num?)?.toInt() ?? rows.length,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// GET {panelBase}/experience-ratings/summary?restaurantId=
  ///
  /// The real business rating (five areas + waiter leaderboard) built from
  /// guest ratings at the table.
  Future<ExperienceSummary> getExperienceSummary(String restaurantId) async {
    try {
      final res = await _api.get(
        '${ApiConstants.panelBase}/experience-ratings/summary?restaurantId=$restaurantId',
      );
      return ExperienceSummary.fromJson(
        panelPayload(res.data) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// GET {panelBase}/experience-ratings?restaurantId=&type=&status=&page=&limit=
  ///
  /// The operational inbox: ratings, complaints and suggestions in one paged
  /// read. `type` and `status` are server filters — filtering a single page
  /// client-side would hide anything that landed on page 2.
  Future<ExperiencePage> getFeedback(
    String restaurantId, {
    int page = 1,
    int limit = experiencePageSize,
    ExperienceType? type,
    ExperienceStatus? status,
  }) async {
    try {
      final StringBuffer q = StringBuffer(
        '${ApiConstants.panelBase}/experience-ratings'
        '?restaurantId=$restaurantId&page=$page&limit=$limit',
      );
      if (type != null) q.write('&type=${experienceTypeWire(type)}');
      if (status != null) q.write('&status=${experienceStatusWire(status)}');

      final res = await _api.get(q.toString());
      final payload = panelPayload(res.data);
      if (payload is! Map) {
        throw const FormatException('The feedback payload was not an object');
      }
      return ExperiencePage.fromPayload(
        Map<String, dynamic>.from(payload),
        fallbackPage: page,
        fallbackLimit: limit,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// PATCH {panelBase}/experience-ratings/:id body {status: read|resolved}
  ///
  /// The server stamps `resolvedBy`/`resolvedAt`; the client never guesses who
  /// handled it.
  Future<ExperienceRating> setFeedbackStatus({
    required String restaurantId,
    required String id,
    required ExperienceStatus status,
  }) async {
    try {
      final res = await _api.patch(
        '${ApiConstants.panelBase}/experience-ratings/$id'
        '?restaurantId=$restaurantId',
        data: <String, dynamic>{'status': experienceStatusWire(status)},
      );
      final payload = panelPayload(res.data);
      final Object? row = payload is Map ? payload['rating'] : null;
      if (row is! Map) {
        throw const FormatException('The feedback payload was not an object');
      }
      return ExperienceRating.fromJson(Map<String, dynamic>.from(row));
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }

  /// POST {panelBase}/reviews/:id/respond body {response} (decision 7).
  Future<PanelReview> respondReview({
    required String restaurantId,
    required String id,
    required String response,
  }) async {
    try {
      final res = await _api.post(
        '${ApiConstants.panelBase}/reviews/$id/respond?restaurantId=$restaurantId',
        data: {'response': response},
      );
      return PanelReview.fromJson(
        panelPayload(res.data) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw parseDioError(e);
    }
  }
}
