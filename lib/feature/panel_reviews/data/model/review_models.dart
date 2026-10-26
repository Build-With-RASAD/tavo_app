// lib/feature/panel_reviews/data/model/review_models.dart
//
// Two different things live here on purpose:
//
//   • [PanelReview] — a public, marketing review (`GET /reviews`). One star
//     score, one comment, sometimes an owner response.
//   • [ExperienceRating] — the operational feedback a guest leaves at the
//     table: a five-area rating, a complaint, or a suggestion. One document
//     type carries all three because staff triage them in one inbox.
//
// Every field is decoded tolerantly: the panel receives legacy rows, nulls and
// numeric strings, and a hard cast used to crash the screen.

/// What the guest left.
enum ExperienceType { review, complaint, suggestion }

/// Where the feedback sits in triage.
///
/// The wire value for the first state is `new`, which is a reserved word in
/// Dart, so it is modelled as [unread] and mapped on the way in and out.
enum ExperienceStatus { unread, read, resolved }

ExperienceType experienceTypeFrom(String? raw) {
  switch (raw) {
    case 'complaint':
      return ExperienceType.complaint;
    case 'suggestion':
      return ExperienceType.suggestion;
    default:
      return ExperienceType.review;
  }
}

String experienceTypeWire(ExperienceType type) => switch (type) {
      ExperienceType.review => 'review',
      ExperienceType.complaint => 'complaint',
      ExperienceType.suggestion => 'suggestion',
    };

ExperienceStatus experienceStatusFrom(String? raw) {
  switch (raw) {
    case 'read':
      return ExperienceStatus.read;
    case 'resolved':
      return ExperienceStatus.resolved;
    default:
      return ExperienceStatus.unread;
  }
}

String experienceStatusWire(ExperienceStatus status) => switch (status) {
      ExperienceStatus.unread => 'new',
      ExperienceStatus.read => 'read',
      ExperienceStatus.resolved => 'resolved',
    };

/// One row of the feedback inbox, with the guest details staff need to follow
/// up: who, which table, which waiter, when.
class ExperienceRating {
  const ExperienceRating({
    required this.id,
    required this.type,
    required this.status,
    required this.scores,
    required this.comment,
    required this.subject,
    required this.guestLabel,
    required this.tableCode,
    required this.createdAt,
    this.photoUrl = '',
    this.waiterMessage = '',
    this.waiterId,
    this.waiterName,
    this.resolvedAt,
  });

  final String id;
  final ExperienceType type;
  final ExperienceStatus status;

  /// Area → score (1–5). A missing key means the guest skipped that area; it
  /// must never be read as zero.
  final Map<String, int?> scores;

  final String comment;
  final String subject;
  final String guestLabel;
  final String tableCode;
  final String photoUrl;
  final String waiterMessage;
  final String? waiterId;
  final String? waiterName;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isResolved => status == ExperienceStatus.resolved;

  /// The guest's headline: the complaint subject wins, then the comment.
  String get headline =>
      subject.isNotEmpty ? subject : (comment.isNotEmpty ? comment : '');

  /// Only the areas the guest actually scored.
  Map<String, int> get scoredAreas => <String, int>{
        for (final MapEntry<String, int?> entry in scores.entries)
          if (entry.value != null) entry.key: entry.value!,
      };

  bool get hasScores => scoredAreas.isNotEmpty;

  /// Mean of the areas the guest scored; null when nothing was scored.
  double? get overall {
    final Map<String, int> values = scoredAreas;
    if (values.isEmpty) return null;
    final int sum = values.values.fold(0, (int a, int b) => a + b);
    return sum / values.length;
  }

  /// Who to show in the list. A guest who typed a name gets it; otherwise the
  /// table is the only honest identifier we have.
  String get displayName {
    if (guestLabel.trim().isNotEmpty) return guestLabel.trim();
    if (tableCode.trim().isNotEmpty) return tableCode.trim();
    return '';
  }

  ExperienceRating copyWith({ExperienceStatus? status, DateTime? resolvedAt}) =>
      ExperienceRating(
        id: id,
        type: type,
        status: status ?? this.status,
        scores: scores,
        comment: comment,
        subject: subject,
        guestLabel: guestLabel,
        tableCode: tableCode,
        createdAt: createdAt,
        photoUrl: photoUrl,
        waiterMessage: waiterMessage,
        waiterId: waiterId,
        waiterName: waiterName,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );

  factory ExperienceRating.fromJson(Map<String, dynamic> json) {
    final Object? rawScores = json['scores'];
    final Object? rawWaiter = json['waiter'];

    return ExperienceRating(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: experienceTypeFrom(json['type'] as String?),
      status: experienceStatusFrom(json['status'] as String?),
      scores: <String, int?>{
        for (final String area in _areaKeys)
          area: _toScore(rawScores is Map ? rawScores[area] : null),
      },
      comment: (json['comment'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      guestLabel: (json['guestLabel'] ?? '').toString(),
      tableCode: (json['tableCode'] ?? '').toString(),
      photoUrl: (json['photoUrl'] ?? '').toString(),
      waiterMessage: (json['waiterMessage'] ?? '').toString(),
      waiterId: rawWaiter is Map ? rawWaiter['id']?.toString() : null,
      waiterName: rawWaiter is Map ? rawWaiter['name']?.toString() : null,
      createdAt: _toDate(json['createdAt']),
      resolvedAt: _toDate(json['resolvedAt']),
    );
  }
}

/// One page of the inbox.
class ExperiencePage {
  const ExperiencePage({
    required this.items,
    required this.page,
    required this.total,
    required this.limit,
  });

  final List<ExperienceRating> items;
  final int page;
  final int total;
  final int limit;

  int get pages => total <= 0 ? 1 : (total / limit).ceil();

  factory ExperiencePage.fromPayload(
    Map<String, dynamic> payload, {
    int fallbackPage = 1,
    int fallbackLimit = experiencePageSize,
  }) {
    final Object? rows = payload['items'];
    final int total = _toInt(payload['total']);
    final int limit = _toInt(payload['limit']);

    return ExperiencePage(
      items: rows is List
          ? rows
              .whereType<Map>()
              .map((row) => ExperienceRating.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .toList()
          : const <ExperienceRating>[],
      page: _toInt(payload['page']) == 0 ? fallbackPage : _toInt(payload['page']),
      total: total,
      limit: limit == 0 ? fallbackLimit : limit,
    );
  }
}

/// Rows per page. The backend clamps to 100; 20 keeps a page scannable.
const int experiencePageSize = 20;

const List<String> _areaKeys = <String>[
  'restaurant',
  'waiter',
  'food',
  'speed',
  'cleanliness',
];

int? _toScore(Object? value) {
  if (value == null) return null;
  final int? parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 1 || parsed > 5) return null;
  return parsed;
}

DateTime? _toDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value')?.toLocal();
}

int _toInt(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}') ?? 0;

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
