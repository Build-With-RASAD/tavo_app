// test/panel_reviews_test.dart
//
// The feedback inbox contract: one page of ratings, complaints and
// suggestions; an overview that explains them; server-side type/status
// filters; a detail sheet that carries the guest, the table, the waiter and
// every score; and a triage write that refreshes the overview.
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

const _manager = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _viewer = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_reviews'],
  status: 'active',
);

ExperienceRating _feedback(
  String id, {
  ExperienceType type = ExperienceType.review,
  ExperienceStatus status = ExperienceStatus.unread,
  String guest = 'Sara',
  String table = 'T1-1',
  String subject = '',
  String comment = 'Great meal',
  Map<String, int?> scores = const <String, int?>{'food': 5, 'speed': 4},
  String? waiterName,
  String waiterMessage = '',
  String photoUrl = '',
}) =>
    ExperienceRating(
      id: id,
      type: type,
      status: status,
      scores: scores,
      comment: comment,
      subject: subject,
      guestLabel: guest,
      tableCode: table,
      waiterName: waiterName,
      waiterMessage: waiterMessage,
      photoUrl: photoUrl,
      createdAt: DateTime(2026, 10, 26, 14, 32),
    );

Map<String, dynamic> _summaryJson({
  int reviews = 1,
  int complaints = 0,
  int suggestions = 0,
  int openComplaints = 0,
}) =>
    <String, dynamic>{
      'count': reviews + complaints + suggestions,
      'scored': reviews,
      'average': reviews == 0 ? null : 4.6,
      'areas': <String, dynamic>{
        'restaurant': 4.8,
        'waiter': 4.5,
        'food': 4.7,
        'speed': 4.2,
        'cleanliness': 4.9,
      },
      'byType': <String, dynamic>{
        'review': reviews,
        'complaint': complaints,
        'suggestion': suggestions,
      },
      'openComplaints': openComplaints,
      'waiters': <dynamic>[],
    };

/// Fake repo: canned rows, a call journal and the exact filter arguments of
/// every read. Filters are applied here the way the server applies them, so a
/// client-side filter regression cannot pass.
class _FakeReviewsRepo extends ReviewsPanelRepo {
  _FakeReviewsRepo() : super(api: ApiService());

  List<ExperienceRating> items = <ExperienceRating>[];
  Map<String, dynamic> summaryJson = _summaryJson();
  Object? failure;
  Object? summaryFailure;
  final List<String> calls = <String>[];
  final List<({int page, ExperienceType? type, ExperienceStatus? status})>
      reads = <({int page, ExperienceType? type, ExperienceStatus? status})>[];

  @override
  Future<ExperienceSummary> getExperienceSummary(String restaurantId) async {
    calls.add('summary');
    if (summaryFailure != null) {
      final Object f = summaryFailure!;
      summaryFailure = null;
      throw f;
    }
    return ExperienceSummary.fromJson(summaryJson);
  }

  @override
  Future<ExperiencePage> getFeedback(
    String restaurantId, {
    int page = 1,
    int limit = experiencePageSize,
    ExperienceType? type,
    ExperienceStatus? status,
  }) async {
    reads.add((page: page, type: type, status: status));
    calls.add('getFeedback:$page:${type?.name ?? '*'}:${status?.name ?? '*'}');
    _maybeThrow();

    Iterable<ExperienceRating> visible = items;
    if (type != null) {
      visible = visible.where((ExperienceRating r) => r.type == type);
    }
    if (status != null) {
      visible = visible.where((ExperienceRating r) => r.status == status);
    }
    final List<ExperienceRating> all = visible.toList();
    return ExperiencePage(
      items: all,
      page: page,
      limit: limit,
      total: all.length,
    );
  }

  @override
  Future<ExperienceRating> setFeedbackStatus({
    required String restaurantId,
    required String id,
    required ExperienceStatus status,
  }) async {
    calls.add('setStatus:$id:${status.name}');
    _maybeThrow();
    final int at = items.indexWhere((ExperienceRating r) => r.id == id);
    items[at] = items[at].copyWith(status: status);
    return items[at];
  }

  void _maybeThrow() {
    final Object? f = failure;
    if (f == null) return;
    failure = null;
    throw f;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeReviewsRepo repo, {
  StaffRestaurant venue = _manager,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  GetIt.instance.registerLazySingleton<ReviewsPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);

  await tester.pumpWidget(appShell(ReviewsScreen(
    restaurantId: 'r1',
    venue: venue,
  )));
  // The fake answers immediately; the extra pump lets the localization shell
  // build its subtree before the loaded frame is asserted.
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnv);

  group('model', () {
    test('decodes the real inbox shape and averages only scored areas', () {
      final ExperienceRating rating =
          ExperienceRating.fromJson(<String, dynamic>{
        'id': 'f1',
        'type': 'complaint',
        'status': 'read',
        'scores': <String, dynamic>{
          'restaurant': 2,
          'waiter': null,
          'food': 4,
        },
        'comment': 'The order was cold',
        'subject': 'Cold food',
        'guestLabel': 'Ahmed',
        'tableCode': 'T4-2',
        'waiter': <String, dynamic>{'id': 'w1', 'name': 'Sara'},
        'createdAt': '2026-10-26T11:32:00.000Z',
      });

      expect(rating.type, ExperienceType.complaint);
      expect(rating.status, ExperienceStatus.read);
      expect(rating.scoredAreas, <String, int>{'restaurant': 2, 'food': 4});
      // 2 and 4 average to 3 — the skipped waiter area is not a zero.
      expect(rating.overall, 3.0);
      expect(rating.waiterName, 'Sara');
      expect(rating.headline, 'Cold food');
      expect(rating.displayName, 'Ahmed');
    });

    test('a message without scores is not a zero-star rating', () {
      final ExperienceRating suggestion =
          ExperienceRating.fromJson(<String, dynamic>{
        'id': 'f2',
        'type': 'suggestion',
        'comment': 'Add allergen notes',
      });

      expect(suggestion.type, ExperienceType.suggestion);
      expect(suggestion.status, ExperienceStatus.unread);
      expect(suggestion.hasScores, isFalse);
      expect(suggestion.overall, isNull);
    });

    test('pages are computed from the server total', () {
      final ExperiencePage page = ExperiencePage.fromPayload(<String, dynamic>{
        'items': <dynamic>[],
        'page': 2,
        'limit': 20,
        'total': 45,
      });

      expect(page.page, 2);
      expect(page.pages, 3);
    });
  });

  group('cubit', () {
    test('loads the overview and one page of everything', () async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('f1'),
          _feedback('f2', type: ExperienceType.complaint),
        ]
        ..summaryJson = _summaryJson(reviews: 1, complaints: 1);

      final ReviewsPanelCubit cubit =
          ReviewsPanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);
      await cubit.load();

      final ReviewsPanelLoaded state = cubit.state as ReviewsPanelLoaded;
      expect(state.items, hasLength(2));
      expect(state.reviewCount, 1);
      expect(state.complaintCount, 1);
      expect(state.allCount, 2);
      // No type/status on the wire when nothing is filtered.
      expect(repo.reads.single.type, isNull);
      expect(repo.reads.single.status, isNull);
    });

    test('type and status are server filters and reset to page one', () async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('f1'),
          _feedback('f2', type: ExperienceType.complaint),
        ];

      final ReviewsPanelCubit cubit =
          ReviewsPanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setType(ExperienceType.complaint);
      expect((cubit.state as ReviewsPanelLoaded).items.single.id, 'f2');
      expect(repo.reads.last.type, ExperienceType.complaint);
      expect(repo.reads.last.page, 1);

      await cubit.setStatus(ExperienceStatus.unread);
      expect(repo.reads.last.status, ExperienceStatus.unread);
      expect(repo.reads.last.type, ExperienceType.complaint);

      await cubit.clearFilters();
      expect(repo.reads.last.type, isNull);
      expect(repo.reads.last.status, isNull);
      expect((cubit.state as ReviewsPanelLoaded).items, hasLength(2));
    });

    test('resolving writes, updates the row and refreshes the overview',
        () async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('c1', type: ExperienceType.complaint),
        ]
        ..summaryJson = _summaryJson(complaints: 1, openComplaints: 1);

      final ReviewsPanelCubit cubit =
          ReviewsPanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.resolve((cubit.state as ReviewsPanelLoaded).items.single);

      expect(repo.calls, contains('setStatus:c1:resolved'));
      final ReviewsPanelLoaded state = cubit.state as ReviewsPanelLoaded;
      expect(state.items.single.status, ExperienceStatus.resolved);
      expect(
        repo.calls.where((String c) => c == 'summary').length,
        2,
        reason: 'the overview must not keep a stale open-complaint count',
      );
    });

    test('a failed triage keeps the row and surfaces the reason', () async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[_feedback('f1')];

      final ReviewsPanelCubit cubit =
          ReviewsPanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);
      await cubit.load();
      repo.failure = Exception('forbidden');

      await cubit.resolve((cubit.state as ReviewsPanelLoaded).items.single);

      final ReviewsPanelLoaded state = cubit.state as ReviewsPanelLoaded;
      expect(state.items.single.status, ExperienceStatus.unread);
      expect(state.actionError, contains('forbidden'));
    });
  });

  group('screen', () {
    testWidgets('loading shows the skeleton before content', (tester) async {
      GetIt.instance.registerLazySingleton<ReviewsPanelRepo>(
        () => _FakeReviewsRepo(),
      );
      addTearDown(GetIt.instance.reset);
      await tester.pumpWidget(appShell(const ReviewsScreen(
        restaurantId: 'r1',
        venue: _manager,
      )));
      await pumpUntil(
        tester,
        () => find.byType(ListSkeleton).evaluate().isNotEmpty,
      );
      expect(find.byType(ListSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ListSkeleton), findsNothing);
    });

    testWidgets('overview explains the numbers, not just the list',
        (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('f1'),
          _feedback('f2', type: ExperienceType.complaint, subject: 'Cold'),
          _feedback('f3', type: ExperienceType.suggestion),
        ]
        ..summaryJson =
            _summaryJson(reviews: 1, complaints: 1, suggestions: 1, openComplaints: 1);

      await _pump(tester, repo);

      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('Food quality'), findsOneWidget);
      expect(find.text('1 complaints need action'), findsOneWidget);
      expect(find.text('Cold'), findsOneWidget);
    });

    testWidgets('tabs are real server filters', (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('f1', guest: 'Sara'),
          _feedback('f2', type: ExperienceType.complaint, guest: 'Ahmed'),
        ]
        ..summaryJson = _summaryJson(reviews: 1, complaints: 1);

      await _pump(tester, repo);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('Ahmed'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('feedback_tab_complaint')),
      );
      await tester.pumpAndSettle();

      expect(repo.reads.last.type, ExperienceType.complaint);
      expect(find.text('Ahmed'), findsOneWidget);
      expect(find.text('Sara'), findsNothing);
    });

    testWidgets('the detail sheet carries the guest, table and every score',
        (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback(
            'f1',
            guest: 'Ahmed',
            table: 'T4-2',
            subject: 'Cold food',
            comment: 'The main course arrived cold',
            waiterName: 'Sara',
            scores: <String, int?>{'food': 2, 'speed': 5},
          ),
        ];

      await _pump(tester, repo);
      await tester.tap(find.byKey(const ValueKey<String>('feedback_row_f1')));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed'), findsWidgets);
      expect(find.text('T4-2'), findsWidgets);
      expect(find.text('Sara'), findsWidgets);
      expect(find.text('The main course arrived cold'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('5/5'), findsOneWidget);
    });

    testWidgets('resolving from the sheet writes and closes it',
        (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[
          _feedback('c1', type: ExperienceType.complaint, subject: 'Cold'),
        ]
        ..summaryJson = _summaryJson(complaints: 1, openComplaints: 1);

      await _pump(tester, repo);
      await tester.tap(find.byKey(const ValueKey<String>('feedback_row_c1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('feedback_resolve')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('setStatus:c1:resolved'));
      expect(
        find.byKey(const ValueKey<String>('feedback_resolve')),
        findsNothing,
        reason: 'the sheet closes once the write lands',
      );
      expect(find.text('Resolved'), findsWidgets);
    });

    testWidgets('view-only staff read the inbox without triage controls',
        (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[_feedback('f1', guest: 'Ahmed')];

      await _pump(tester, repo, venue: _viewer);
      expect(find.text('Ahmed'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('feedback_row_f1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Read only — you cannot triage feedback'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('feedback_resolve')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('feedback_mark_read')),
        findsNothing,
      );
    });

    testWidgets('an empty inbox explains the next step', (tester) async {
      await _pump(tester, _FakeReviewsRepo());
      expect(find.text('No feedback here yet'), findsOneWidget);
      expect(
        find.text(
          'Guest ratings, complaints and suggestions will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a summary failure never hides the feedback', (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..items = <ExperienceRating>[_feedback('f1', guest: 'Sara')]
        ..summaryFailure = Exception('summary down');

      await _pump(tester, repo);

      expect(find.text('Sara'), findsOneWidget);
      expect(
        find.textContaining('The overview is unavailable'),
        findsOneWidget,
      );
    });

    testWidgets('a page failure is an error with a working retry',
        (tester) async {
      final _FakeReviewsRepo repo = _FakeReviewsRepo()
        ..failure = Exception('Network down');

      await _pump(tester, repo);
      expect(find.textContaining('Network down'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('No feedback here yet'), findsOneWidget);
    });
  });
}
