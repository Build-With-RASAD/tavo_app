// lib/feature/panel_reviews/data/model/review_models.dart
class PanelReview {
  const PanelReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.userName,
    required this.createdAt,
    this.avatarUrl,
    this.ownerResponse,
  });

  final String id;
  final int rating;
  final String comment;
  final String userName;
  final String createdAt;
  final String? avatarUrl;
  final String? ownerResponse;

  factory PanelReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return PanelReview(
      id: json['_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      userName: user is Map ? user['name'] as String? ?? '' : '',
      avatarUrl: user is Map ? user['avatar'] as String? : null,
      createdAt: json['createdAt'] as String? ?? '',
      ownerResponse: json['ownerResponse'] as String?,
    );
  }
}
