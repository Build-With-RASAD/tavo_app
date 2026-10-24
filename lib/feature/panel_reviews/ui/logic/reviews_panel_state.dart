// ui/logic/reviews_panel_state.dart
part of 'reviews_panel_cubit.dart';

sealed class ReviewsPanelState {
  const ReviewsPanelState();
}

class ReviewsPanelInitial extends ReviewsPanelState {
  const ReviewsPanelInitial();
}

class ReviewsPanelLoading extends ReviewsPanelState {
  const ReviewsPanelLoading();
}

class ReviewsPanelLoaded extends ReviewsPanelState {
  const ReviewsPanelLoaded({
    required this.reviews,
    required this.page,
    required this.pages,
    required this.total,
    this.summary,
    this.actionId,
    this.actionError,
    this.filterRating,
  });

  final List<PanelReview> reviews;
  final int page;
  final int pages;
  final int total;

  /// Real 0–5 business rating + waiter leaderboard; null until the summary
  /// call lands (or when it fails — the list must not depend on it).
  final ExperienceSummary? summary;

  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the list on screen
  final int? filterRating; // null = all ratings (server-side filter)

  ReviewsPanelLoaded copyWith({
    List<PanelReview>? reviews,
    int? page,
    int? pages,
    int? total,
    ExperienceSummary? summary,
    String? actionId,
    String? actionError,
    int? filterRating,
    bool clearAction = false,
    bool clearError = false,
    bool clearFilter = false,
  }) =>
      ReviewsPanelLoaded(
        reviews: reviews ?? this.reviews,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        total: total ?? this.total,
        summary: summary ?? this.summary,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
        // `filterRating: null` must clear the filter, so clearing is an
        // explicit flag rather than the nullable value itself.
        filterRating:
            clearFilter ? null : filterRating ?? this.filterRating,
      );
}

class ReviewsPanelError extends ReviewsPanelState {
  const ReviewsPanelError(this.message);
  final String message;
}
