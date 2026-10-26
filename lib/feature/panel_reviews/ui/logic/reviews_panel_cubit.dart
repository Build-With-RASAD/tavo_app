// ui/logic/reviews_panel_cubit.dart
//
// The feedback inbox: ratings, complaints and suggestions in one paged list,
// with the overview that explains them.
//
// Two reads per load, both independent: the summary (averages, rows per type,
// open complaints) and one page of the active tab. A failed summary leaves the
// list readable; only a failed page is a real error. Filters are server-side —
// `type` and `status` go on the wire, never through a local `where`.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/experience_summary.dart';
import '../../data/model/review_models.dart';
import '../../data/repo/reviews_panel_repo.dart';

part 'reviews_panel_state.dart';

class ReviewsPanelCubit extends Cubit<ReviewsPanelState> {
  ReviewsPanelCubit(this._repo, {required this.restaurantId})
      : super(const ReviewsPanelInitial());

  final ReviewsPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const ReviewsPanelLoading());

    final Future<ExperienceSummary?> summaryFuture = _repo
        .getExperienceSummary(restaurantId)
        .then<ExperienceSummary?>((ExperienceSummary value) => value)
        .catchError((Object _) => null);

    try {
      final ExperiencePage page = await _repo.getFeedback(restaurantId);
      final ExperienceSummary? summary = await summaryFuture;
      if (isClosed) return;
      emit(ReviewsPanelLoaded(
        items: page.items,
        page: page.page,
        pages: page.pages,
        total: page.total,
        summary: summary,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(ReviewsPanelError(_message(e)));
    }
  }

  /// Switch tab: `null` = everything. Refetches from page one.
  Future<void> setType(ExperienceType? type) async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded || s.type == type) return;
    await _refetch(
      s.copyWith(type: type, clearType: type == null, page: 1),
    );
  }

  /// Triage filter: unread / read / resolved.
  Future<void> setStatus(ExperienceStatus? status) async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded || s.status == status) return;
    await _refetch(
      s.copyWith(status: status, clearStatus: status == null, page: 1),
    );
  }

  Future<void> clearFilters() async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded || !s.hasFilters) return;
    await _refetch(
      s.copyWith(
        type: null,
        status: null,
        clearType: true,
        clearStatus: true,
        page: 1,
      ),
    );
  }

  Future<void> goToPage(int page) async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded || page < 1 || page > s.pages) return;
    await _refetch(s.copyWith(page: page));
  }

  /// Loads the current filters at the already-decided page.
  Future<void> refresh() async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded) return;
    await _refetch(s);
  }

  Future<void> _refetch(ReviewsPanelLoaded next) async {
    // Filters are visible immediately; the rows keep their place until the
    // server answers, so the screen never flashes an empty list.
    emit(next);
    try {
      final ExperiencePage page = await _repo.getFeedback(
        restaurantId,
        page: next.page,
        type: next.type,
        status: next.status,
      );
      if (isClosed) return;
      emit(next.copyWith(
        items: page.items,
        page: page.page,
        pages: page.pages,
        total: page.total,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(next.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Marks one row read, then refreshes the summary (the open-complaint count
  /// is part of the overview and must not go stale behind a local edit).
  Future<void> markRead(ExperienceRating rating) =>
      _triage(rating, ExperienceStatus.read);

  Future<void> resolve(ExperienceRating rating) =>
      _triage(rating, ExperienceStatus.resolved);

  Future<void> _triage(
    ExperienceRating rating,
    ExperienceStatus status,
  ) async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded || s.actionId != null) return;
    if (rating.status == status) return;
    emit(s.copyWith(actionId: rating.id, clearError: true));

    try {
      final ExperienceRating updated = await _repo.setFeedbackStatus(
        restaurantId: restaurantId,
        id: rating.id,
        status: status,
      );
      if (isClosed) return;

      final bool hiddenByStatus = s.status != null && s.status != updated.status;
      emit(s.copyWith(
        items: hiddenByStatus
            ? s.items.where((ExperienceRating r) => r.id != rating.id).toList()
            : <ExperienceRating>[
                for (final ExperienceRating r in s.items)
                  if (r.id == updated.id) updated else r,
              ],
        total: hiddenByStatus ? (s.total - 1).clamp(0, s.total) : s.total,
        clearAction: true,
      ));

      await _refreshSummary();
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> _refreshSummary() async {
    final ReviewsPanelState s = state;
    if (s is! ReviewsPanelLoaded) return;
    try {
      final ExperienceSummary summary =
          await _repo.getExperienceSummary(restaurantId);
      if (isClosed) return;
      emit((state as ReviewsPanelLoaded).copyWith(summary: summary));
    } catch (_) {
      // The overview is decoration; a stale count is better than an error.
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
