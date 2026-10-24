// test/panel_waitlist_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';
import 'package:tavo/feature/panel_waitlist/data/repo/waitlist_panel_repo.dart';
import 'package:tavo/feature/panel_waitlist/ui/logic/waitlist_panel_cubit.dart';
import 'package:tavo/feature/panel_waitlist/ui/widgets/add_walkin_sheet.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/waitlist_tab.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';

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

PanelWaitlistEntry _entry(String id, String status,
        {String ticket = 'A1', int guests = 2}) =>
    PanelWaitlistEntry(
      id: id,
      ticketCode: ticket,
      guestsCount: guests,
      customerName: 'Walk-in $id',
      customerPhone: '+966500000001',
      status: status,
      createdAt: DateTime.now()
          .subtract(const Duration(minutes: 12))
          .toIso8601String(),
    );

class _FakeWaitlistRepo extends WaitlistPanelRepo {
  _FakeWaitlistRepo() : super(api: ApiService());
  List<PanelWaitlistEntry> entries = [];
  int pages = 1;
  Object? failure;
  final List<String> calls = [];

  // Timer-based latency (not a microtask) so multi-frame states stay
  // observable: the skeleton after pumpWidget+pump, the per-row spinner
  // after tap+pump. A real repo is a network call, which always spans
  // frames; an instant fake would skip those frames entirely.
  static const _latency = Duration(milliseconds: 10);

  /// The walk-in the sheet created (null until one is submitted).
  PanelWaitlistEntry? created;

  @override
  Future<PanelWaitlistEntry> createWaitlistEntry({
    required String restaurantId,
    required int guestsCount,
    required String name,
    required String phone,
    String? email,
    String? specialRequests,
  }) async {
    calls.add('createWalkin:$name');
    await Future<void>.delayed(_latency);
    _maybeThrow();
    final entry = PanelWaitlistEntry(
      id: 'w1',
      ticketCode: 'W1',
      guestsCount: guestsCount,
      customerName: name,
      customerPhone: phone,
      status: 'waiting',
      createdAt: DateTime.now().toIso8601String(),
      notes: specialRequests,
    );
    created = entry;
    // The queue the staff member sees must contain the new entry.
    entries = [entry, ...entries];
    return entry;
  }

  @override
  Future<({List<PanelWaitlistEntry> entries, int page, int pages, int total})>
      getWaitlist(String restaurantId, {int page = 1, String? status}) async {
    calls.add('getWaitlist:$page:${status ?? '*'}');
    await Future<void>.delayed(_latency);
    _maybeThrow();
    return (entries: entries, page: page, pages: pages, total: entries.length);
  }

  @override
  Future<PanelWaitlistEntry> transition(
      {required String restaurantId,
      required String id,
      required String action}) async {
    calls.add('transition:$id:$action');
    await Future<void>.delayed(_latency);
    _maybeThrow();
    const next = {
      'notify': 'notified',
      'confirm': 'confirmed',
      'no-show': 'no_show',
      'cancel': 'cancelled',
    };
    final i = entries.indexWhere((e) => e.id == id);
    entries[i] = PanelWaitlistEntry(
      id: entries[i].id,
      ticketCode: entries[i].ticketCode,
      guestsCount: entries[i].guestsCount,
      customerName: entries[i].customerName,
      customerPhone: entries[i].customerPhone,
      status: next[action] ?? action,
      createdAt: entries[i].createdAt,
    );
    return entries[i];
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpWaitlist(WidgetTester tester, _FakeWaitlistRepo repo) async {
  GetIt.instance.registerLazySingleton<WaitlistPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  addTearDown(() => waitlistBadgeCount.value = 0);
  await tester.pumpWidget(
      appShell(WaitlistTab(restaurantId: 'r1', venue: _venue)));
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton, then the queue + shell badge',
      (tester) async {
    final repo = _FakeWaitlistRepo()
      ..entries = [
        _entry('e1', 'waiting'),
        // Distinct ticket: both entries default to 'A1', which would make
        // the `find.text('A1')` ticket-code assertion ambiguous.
        _entry('e2', 'notified', ticket: 'A2'),
      ];
    await _pumpWaitlist(tester, repo);
    // Frame 1 belongs to EasyLocalization (child not built yet); frame 2
    // builds the tab while the fake load is still in flight.
    await tester.pump();
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Walk-in e1'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget); // ticket code
    expect(waitlistBadgeCount.value, 2); // waiting + notified feed the badge
  });

  testWidgets('empty queue shows the composed empty state', (tester) async {
    await _pumpWaitlist(tester, _FakeWaitlistRepo());
    await tester.pumpAndSettle();
    expect(find.text('No one is waiting right now'), findsOneWidget);
    expect(waitlistBadgeCount.value, 0);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeWaitlistRepo()..failure = Exception('boom');
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Iconsax.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('getWaitlist:1:*'));
  });

  testWidgets('notify fires directly with a per-row spinner', (tester) async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action_e1_notify')));
    await tester.pump(); // spinner frame
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('transition:e1:notify'));
    // Scoped to the card: the `notified` filter chip renders the same
    // translated label.
    expect(
      find.descendant(
        of: find.byKey(const Key('wait_e1')),
        matching: find.text('Notified'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancel goes through the confirm action sheet',
      (tester) async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('action_e1_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm this action?'), findsOneWidget);
    await tester.tap(find.text('Yes, do it'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('transition:e1:cancel'));
    // Scoped to the card: the `cancelled` filter chip renders the same
    // translated label.
    expect(
      find.descendant(
        of: find.byKey(const Key('wait_e1')),
        matching: find.text('Cancelled'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('status chips refetch with the server-side filter',
      (tester) async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter_waitlist_notified')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('getWaitlist:1:notified'));
  });

  testWidgets('the walk-in sheet creates an entry that lands in the queue',
      (tester) async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('waitlist_add_walkin')));
    await tester.pumpAndSettle();
    expect(find.byType(AddWalkinSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('dash_field_name')),
      'Nadia',
    );
    await tester.enterText(
      find.byKey(const Key('dash_field_phone')),
      '+966500000009',
    );
    await tester.enterText(
      find.byKey(const Key('dash_field_guests')),
      '4',
    );
    await tester.enterText(
      find.byKey(const Key('dash_field_email')),
      'nadia@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('dash_field_notes')),
      'Window seat',
    );

    await tester.tap(find.byKey(const Key('dash_submit')));
    await tester.pumpAndSettle();

    // The sheet closed and the entry reached the backend…
    expect(find.byType(AddWalkinSheet), findsNothing);
    expect(repo.created, isNotNull);
    expect(repo.created!.customerName, 'Nadia');
    expect(repo.created!.customerPhone, '+966500000009');
    expect(repo.created!.guestsCount, 4);
    expect(repo.created!.notes, 'Window seat');
    // …and it is in the queue, visible without leaving the tab.
    expect(find.text('Nadia'), findsOneWidget);
    expect(repo.calls, contains('createWalkin:Nadia'));
  });

  testWidgets('a failing walk-in keeps the sheet open with the message',
      (tester) async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    await _pumpWaitlist(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('waitlist_add_walkin')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('dash_field_name')),
      'Nadia',
    );
    await tester.enterText(
      find.byKey(const Key('dash_field_phone')),
      '+966500000009',
    );

    repo.failure = Exception('walk-in rejected');
    await tester.tap(find.byKey(const Key('dash_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(AddWalkinSheet), findsOneWidget);
    // The message is beside the form. It also lands on the queue behind the
    // sheet (the same `actionError`), so the finder is scoped to the sheet.
    expect(
      find.descendant(
        of: find.byType(AddWalkinSheet),
        matching: find.textContaining('walk-in rejected'),
      ),
      findsOneWidget,
    );
  });

  test('nextWaitlistActions mirrors the backend transition table', () {
    expect(nextWaitlistActions('waiting'),
        ['notify', 'confirm', 'no-show', 'cancel']);
    expect(nextWaitlistActions('notified'), ['confirm', 'no-show', 'cancel']);
    expect(nextWaitlistActions('confirmed'), isEmpty);
    expect(nextWaitlistActions('cancelled'), isEmpty);
  });

  test('transition failure keeps the row and surfaces actionError', () async {
    final repo = _FakeWaitlistRepo()..entries = [_entry('e1', 'waiting')];
    final cubit = WaitlistPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    // Set AFTER load: the fake throws one-shot on the next repo call, so
    // setting it before load would fail the load instead of the transition
    // (house pattern mirrors panel_reservations_test.dart).
    repo.failure = Exception('illegal transition');

    await cubit.transition(_entry('e1', 'waiting'), 'confirm');

    final loaded = cubit.state as WaitlistPanelLoaded;
    expect(loaded.entries.single.status, 'waiting');
    expect(loaded.actionError, contains('illegal transition'));
  });
}
