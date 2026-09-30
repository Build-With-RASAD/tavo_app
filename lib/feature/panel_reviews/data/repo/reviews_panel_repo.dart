// lib/feature/panel_reviews/data/repo/reviews_panel_repo.dart
import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/network/panel_envelope.dart';

import '../model/review_models.dart';

class ReviewsPanelRepo {
  ReviewsPanelRepo({required ApiService api}) : _api = api;
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
