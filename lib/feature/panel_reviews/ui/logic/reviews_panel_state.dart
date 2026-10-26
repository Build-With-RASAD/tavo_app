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
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
    this.summary,
    this.type,
    this.status,
    this.actionId,
    this.actionError,
  });

  /// The current page of the active tab.
  final List<ExperienceRating> items;

  final int page;
  final int pages;
  final int total;

  /// Real 0–5 business rating + the three feedback counts; null until the
  /// summary call lands (or when it fails — the inbox must not depend on it).
  final ExperienceSummary? summary;

  /// Active server-side filters. `type == null` means "everything".
  final ExperienceType? type;
  final ExperienceStatus? status;

  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the list on screen

  /// Rows per tab, straight from the server aggregate.
  int get reviewCount => summary?.byType['review'] ?? 0;
  int get complaintCount => summary?.byType['complaint'] ?? 0;
  int get suggestionCount => summary?.byType['suggestion'] ?? 0;
  int get allCount => reviewCount + complaintCount + suggestionCount;

  /// Complaints that still need someone to act.
  int get openComplaints => summary?.openComplaints ?? 0;

  bool get hasFilters => type != null || status != null;

  ReviewsPanelLoaded copyWith({
    List<ExperienceRating>? items,
    int? page,
    int? pages,
    int? total,
    ExperienceSummary? summary,
    ExperienceType? type,
    ExperienceStatus? status,
    String? actionId,
    String? actionError,
    bool clearAction = false,
    bool clearError = false,
    bool clearType = false,
    bool clearStatus = false,
  }) =>
      ReviewsPanelLoaded(
        items: items ?? this.items,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        total: total ?? this.total,
        summary: summary ?? this.summary,
        // `null` is a real filter value ("all"), so clearing is an explicit
        // flag rather than the nullable value itself.
        type: clearType ? null : type ?? this.type,
        status: clearStatus ? null : status ?? this.status,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
      );
}

class ReviewsPanelError extends ReviewsPanelState {
  const ReviewsPanelError(this.message);
  final String message;
}
