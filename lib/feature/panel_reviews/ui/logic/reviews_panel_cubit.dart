// ui/logic/reviews_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/experience_summary.dart';
import '../../data/model/review_models.dart';
import '../../data/repo/reviews_panel_repo.dart';

part 'reviews_panel_state.dart';

/// Staff panel reviews list: server-side rating filter, page navigation and
/// per-row owner responses.
///
/// Error style mirrors `PanelMenuCubit` (plain strings): `load` failures emit
/// [ReviewsPanelError]; mutation failures keep the loaded list and surface a
/// transient [ReviewsPanelLoaded.actionError] beside it.
class ReviewsPanelCubit extends Cubit<ReviewsPanelState> {
  ReviewsPanelCubit(this._repo, {required this.restaurantId})
      : super(const ReviewsPanelInitial());

  final ReviewsPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const ReviewsPanelLoading());
    try {
      // The summary is decoration on top of the list: if it fails, the
      // reviews still render (and the card shows its empty state).
      final summaryFuture = _repo
          .getExperienceSummary(restaurantId)
          .then<ExperienceSummary?>((value) => value)
          .catchError((Object _) => null);

      final out = await _repo.getReviews(restaurantId);
      final summary = await summaryFuture;
      if (isClosed) return;
      emit(ReviewsPanelLoaded(
        reviews: out.reviews,
        page: out.page,
        pages: out.pages,
        total: out.total,
        summary: summary,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(ReviewsPanelError(_message(e)));
    }
  }

  /// Server-side rating filter (`null` = all ratings): refetches from page 1.
  Future<void> setRating(int? rating) async {
    final s = state;
    if (s is! ReviewsPanelLoaded || s.filterRating == rating) return;
    emit(s.copyWith(filterRating: rating, clearFilter: rating == null));
    await _reload(page: 1);
  }

  Future<void> goToPage(int page) async {
    final s = state;
    if (s is! ReviewsPanelLoaded || page < 1 || page > s.pages) return;
    await _reload(page: page);
  }

  Future<void> _reload({int? page}) async {
    final s = state;
    if (s is! ReviewsPanelLoaded) return;
    try {
      final out = await _repo.getReviews(
        restaurantId,
        page: page ?? s.page,
        rating: s.filterRating,
      );
      if (isClosed) return;
      emit(s.copyWith(
        reviews: out.reviews,
        page: out.page,
        pages: out.pages,
        total: out.total,
        clearAction: true,
        clearError: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Posts the owner response and swaps the row; failures keep the list and
  /// surface [ReviewsPanelLoaded.actionError].
  Future<void> respond(String id, String text) async {
    final s = state;
    if (s is! ReviewsPanelLoaded) return;
    emit(s.copyWith(actionId: id, clearError: true));
    try {
      final updated = await _repo.respondReview(
          restaurantId: restaurantId, id: id, response: text);
      if (isClosed) return;
      emit(s.copyWith(
        reviews: [for (final r in s.reviews) if (r.id == id) updated else r],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
