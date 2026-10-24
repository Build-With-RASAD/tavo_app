// test/panel_reviews_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_reviews/data/model/experience_summary.dart';
import 'package:tavo/feature/panel_reviews/data/model/review_models.dart';
import 'package:tavo/feature/panel_reviews/data/repo/reviews_panel_repo.dart';
import 'package:tavo/feature/panel_reviews/ui/logic/reviews_panel_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/reviews_screen.dart';

import 'helpers/app_shell.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _venue = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _venueView = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_reviews'],
  status: 'active',
);

PanelReview _review(String id, int rating, String comment, {String? response}) =>
    PanelReview(
        id: id,
        rating: rating,
        comment: comment,
        userName: 'Sara',
        createdAt: '2026-09-30T10:00:00.000Z',
        ownerResponse: response);

class _FakeReviewsRepo extends ReviewsPanelRepo {
  _FakeReviewsRepo() : super(api: ApiService());
  List<PanelReview> reviews = [];
  int pages = 1;
  Object? failure;
  final List<String> calls = [];

  /// Wire-shaped summary; tests replace it to exercise the rating card.
  Map<String, dynamic> summaryJson = const {};
  Object? summaryFailure;

  @override
  Future<ExperienceSummary> getExperienceSummary(String restaurantId) async {
    calls.add('summary:$restaurantId');
    if (summaryFailure != null) {
      final f = summaryFailure;
      summaryFailure = null;
      throw f!;
    }
    return ExperienceSummary.fromJson(summaryJson);
  }

  @override
  Future<({List<PanelReview> reviews, int page, int pages, int total})>
      getReviews(String restaurantId, {int page = 1, int? rating}) async {
    calls.add('getReviews:$page:${rating ?? '*'}');
    _maybeThrow();
    return (reviews: reviews, page: page, pages: pages, total: reviews.length);
  }

  @override
  Future<PanelReview> respondReview(
      {required String restaurantId,
      required String id,
      required String response}) async {
    calls.add('respond:$id');
    _maybeThrow();
    final i = reviews.indexWhere((r) => r.id == id);
    reviews[i] = PanelReview(
      id: reviews[i].id,
      rating: reviews[i].rating,
      comment: reviews[i].comment,
      userName: reviews[i].userName,
      createdAt: reviews[i].createdAt,
      ownerResponse: response,
    );
    return reviews[i];
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpReviews(WidgetTester tester, _FakeReviewsRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<ReviewsPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(
      appShell(ReviewsScreen(restaurantId: 'r1', venue: venue)));
  // Mirrors panel_menu_test: EasyLocalization builds the child subtree
  // asynchronously, so wait for the skeleton before asserting on it.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    await _pumpReviews(tester, _FakeReviewsRepo());
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('empty reviews show the composed empty state', (tester) async {
    await _pumpReviews(tester, _FakeReviewsRepo());
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeReviewsRepo()..failure = Exception('boom');
    await _pumpReviews(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Iconsax.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('getReviews:1:*'));
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('renders reviews and responds through the bottom sheet',
      (tester) async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('v1', 5, 'Amazing burger')];
    await _pumpReviews(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Amazing burger'), findsOneWidget);
    expect(find.text('No response yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('respond_v1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('response_field')), 'Thank you!');
    await tester.tap(find.byKey(const Key('submit_response')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('respond:v1'));
    expect(find.text('Thank you!'), findsOneWidget);
    expect(find.text('Responded'), findsOneWidget);
  });

  testWidgets('shows the real business rating and waiter leaderboard',
      (tester) async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('r1', 5, 'Great')]
      ..summaryJson = const {
        'count': 24,
        'scored': 20,
        'average': 4.6,
        'areas': {
          'restaurant': 4.8,
          'waiter': 4.5,
          'food': 4.7,
          'speed': 4.2,
          'cleanliness': 4.9,
        },
        'byType': {'review': 20, 'complaint': 3, 'suggestion': 1},
        'openComplaints': 2,
        'waiters': [
          {'staffId': 's1', 'name': 'Ahmed', 'count': 12, 'average': 4.9},
          {'staffId': 's2', 'name': 'Sara', 'count': 8, 'average': 4.3},
        ],
      };

    await _pumpReviews(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('20 ratings'), findsOneWidget);
    expect(find.text('Waiter leaderboard'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('2 Open complaints'), findsOneWidget);
  });

  testWidgets('a summary failure never blocks the review list',
      (tester) async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('r1', 4, 'Good')]
      ..summaryFailure = Exception('summary down');

    await _pumpReviews(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Sara'), findsWidgets); // the review row still renders
    expect(find.text('No guest ratings yet'), findsOneWidget);
  });

  testWidgets('rating chips refetch with the server-side rating filter',
      (tester) async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('v1', 5, 'Amazing'), _review('v2', 2, 'Cold')];
    await _pumpReviews(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter_rating_5')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('getReviews:1:5'));
  });

  testWidgets('hides respond controls from view-only staff', (tester) async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('v1', 5, 'Amazing burger')];
    await _pumpReviews(tester, repo, venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.text('Amazing burger'), findsOneWidget);
    expect(find.byKey(const Key('respond_v1')), findsNothing);
  });

  test('respond failure keeps the row and surfaces actionError', () async {
    final repo = _FakeReviewsRepo()
      ..reviews = [_review('v1', 5, 'Amazing')];
    final cubit = ReviewsPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    // Arm the failure AFTER load: the fake throws once on the next call, and
    // the behavior under test is the respond failure (not the load failure).
    repo.failure = Exception('too long');

    await cubit.respond('v1', 'x' * 2000);

    final loaded = cubit.state as ReviewsPanelLoaded;
    expect(loaded.reviews.single.ownerResponse, isNull);
    expect(loaded.actionError, contains('too long'));
  });
}
