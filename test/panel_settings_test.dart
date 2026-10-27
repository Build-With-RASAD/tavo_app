// test/panel_settings_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_settings/data/model/settings_models.dart';
import 'package:tavo/feature/panel_settings/data/repo/settings_panel_repo.dart';
import 'package:tavo/feature/panel_settings/ui/logic/settings_panel_cubit.dart';
import 'package:tavo/feature/panel_settings/ui/screens/panel_settings_screen.dart';

import 'helpers/app_shell.dart';

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
  permissions: ['view_reports'],
  status: 'active',
);

List<WorkingDayEntry> _week({bool fridayClosed = false}) => [
      for (final d in kWeekDays)
        WorkingDayEntry(
            day: d,
            openTime: '09:00',
            closeTime: '23:00',
            isClosed: fridayClosed && d == 'friday'),
    ];

class _FakeSettingsRepo extends SettingsPanelRepo {
  _FakeSettingsRepo() : super(api: ApiService());
  List<WorkingDayEntry> days = [];
  ReservationSettings rs = const ReservationSettings(
      slotDurationMinutes: 60,
      specialMenuAvailable: false,
      needsAdvanceNotice: true,
      minAdvanceNoticeDays: 3);
  Object? failure;
  final List<String> calls = [];

  /// The last booking-rules object the screen handed over, so a test can
  /// assert the whole payload instead of one field.
  ReservationSettings? lastRs;

  @override
  Future<
      ({
        List<WorkingDayEntry> workingHours,
        ReservationSettings reservationSettings,
        Map<String, dynamic> celebrationFeatures
      })> getSettings(String restaurantId) async {
    calls.add('getSettings');
    _maybeThrow();
    return (
      workingHours: days,
      reservationSettings: rs,
      celebrationFeatures: const <String, dynamic>{}
    );
  }

  @override
  Future<List<WorkingDayEntry>> updateWorkingHours(
      String restaurantId, List<WorkingDayEntry> next) async {
    calls.add('hours:${next.where((d) => d.isClosed).length}');
    _maybeThrow();
    days = next;
    return days;
  }

  @override
  Future<ReservationSettings> updateReservationSettings(
      String restaurantId, ReservationSettings next) async {
    calls.add('rs:${next.slotDurationMinutes}:${next.minAdvanceNoticeDays}');
    _maybeThrow();
    lastRs = next;
    rs = next;
    return rs;
  }

  @override
  Future<
      ({
        ReservationSettings reservationSettings,
        List<WorkingDayEntry> workingHours
      })> getAvailability(String restaurantId) async {
    _maybeThrow();
    return (reservationSettings: rs, workingHours: days);
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpSettings(WidgetTester tester, _FakeSettingsRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<SettingsPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester
      .pumpWidget(appShell(PanelSettingsScreen(restaurantId: 'r1', venue: venue)));
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('renders all 7 day rows plus the reservation form',
      (tester) async {
    await _pumpSettings(tester, _FakeSettingsRepo()..days = _week());
    await tester.pumpAndSettle();

    expect(find.text('Working hours'), findsOneWidget);
    for (final d in ['sunday', 'saturday']) {
      expect(find.byKey(Key('wh_open_$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('rs_slot')), findsOneWidget);
    expect(find.byKey(const Key('save_hours')), findsOneWidget);
    expect(find.byKey(const Key('save_settings')), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeSettingsRepo()..failure = Exception('boom');
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'getSettings'), hasLength(2));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Working hours'), findsOneWidget);
  });

  testWidgets('saving hours journals the closed-day count', (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();

    // The screen has grown (venue strip, jump rail, occasion section), so in
    // the 600 px test window Friday sits below the fold.
    await tester.ensureVisible(find.byKey(const Key('wh_closed_friday')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wh_closed_friday')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_hours')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('hours:1'));
  });

  testWidgets('saving reservation settings journals slot and notice',
      (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('rs_slot')), '90');
    await tester.enterText(find.byKey(const Key('rs_advance')), '1');
    await tester.tap(find.byKey(const Key('save_settings')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('rs:90:1'));
  });

  testWidgets('view-only staff sees read-only rows, no saves',
      (tester) async {
    await _pumpSettings(tester, _FakeSettingsRepo()..days = _week(),
        venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.text('Working hours'), findsOneWidget);
    expect(find.byKey(const Key('save_hours')), findsNothing);
    expect(find.byKey(const Key('save_settings')), findsNothing);
  });

  test('save failure keeps the form and surfaces actionError', () async {
    final repo = _FakeSettingsRepo()..days = _week();
    final cubit = SettingsPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    expect((cubit.state as SettingsPanelLoaded).days, hasLength(7));

    repo.failure = Exception('invalid hours');
    await cubit.saveWorkingHours(_week());

    final loaded = cubit.state as SettingsPanelLoaded;
    expect(loaded.days, hasLength(7)); // form kept
    expect(loaded.actionError, contains('invalid hours'));
    expect(loaded.saving, isFalse);
  });

  // -------------------------------------------------------------------------
  // The enhanced screen. Each test pins a behaviour the old screen either got
  // wrong (rules it never sent) or did not have (occasion packages, deposit
  // reveal, client-side validation, bulk hours).
  // -------------------------------------------------------------------------

  test('a successful save records when it happened', () async {
    final repo = _FakeSettingsRepo()..days = _week();
    final cubit = SettingsPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    expect((cubit.state as SettingsPanelLoaded).lastSavedAt, isNull);

    await cubit.saveReservationSettings(const ReservationSettings());

    final loaded = cubit.state as SettingsPanelLoaded;
    expect(loaded.lastSavedAt, isNotNull);
    expect(loaded.actionError, isNull);
  });

  testWidgets('the whole booking-rules object is sent, not just the old four',
      (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('cf_birthday')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cf_birthday')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_settings')));
    await tester.pumpAndSettle();

    final sent = repo.lastRs!;
    expect(sent.offersBirthdayPackage, isTrue);
    // The fields the old screen silently reset to schema defaults:
    expect(sent.maxDaysInAdvance, 14);
    expect(sent.bufferTimeMinutes, 15);
    expect(sent.maxPartySize, 20);
    expect(sent.cancellationWindowMinutes, 120);
    expect(sent.allowWaitlist, isTrue);
  });

  testWidgets('deposit fields appear only while a deposit is required',
      (tester) async {
    await _pumpSettings(tester, _FakeSettingsRepo()..days = _week());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('rs_require_deposit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rs_deposit_amount')), findsNothing);

    await tester.tap(find.byKey(const Key('rs_require_deposit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rs_deposit_amount')), findsOneWidget);
    expect(find.byKey(const Key('rs_deposit_threshold')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rs_require_deposit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rs_deposit_amount')), findsNothing);
  });

  testWidgets('an upside-down party range blocks the save', (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('rs_min_party')), '10');
    await tester.enterText(find.byKey(const Key('rs_max_party')), '4');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_settings')));
    await tester.pumpAndSettle();

    expect(find.text('Minimum party size cannot exceed the maximum.'),
        findsOneWidget);
    expect(repo.calls.where((call) => call.startsWith('rs:')), isEmpty);
  });

  testWidgets('a malformed time never reaches the API', (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('wh_open_sunday')), '99:99');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_hours')));
    await tester.pumpAndSettle();

    expect(find.textContaining('HH:mm'), findsOneWidget);
    expect(repo.calls.where((call) => call.startsWith('hours:')), isEmpty);
  });

  testWidgets('apply-to-all copies the first open window onto every open day',
      (tester) async {
    await _pumpSettings(tester, _FakeSettingsRepo()..days = _week());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('wh_open_sunday')), '10:30');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hours_copy_all')));
    await tester.pumpAndSettle();

    final saturdayField = find.descendant(
      of: find.byKey(const Key('wh_open_saturday')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(saturdayField).controller!.text, '10:30');
  });

  testWidgets('the save buttons stay disabled until something changes',
      (tester) async {
    await _pumpSettings(tester, _FakeSettingsRepo()..days = _week());
    await tester.pumpAndSettle();

    expect(
      tester.widget<TavoButton>(find.byKey(const Key('save_hours'))).onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('rs_slot')), '45');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TavoButton>(find.byKey(const Key('save_settings')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('lays out on a phone and reflows into two columns on a tablet',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Phone: single column, and nothing overflows.
    tester.view.physicalSize = const Size(390, 844);
    GetIt.instance.registerLazySingleton<SettingsPanelRepo>(
        () => _FakeSettingsRepo()..days = _week());
    addTearDown(GetIt.instance.reset);
    await tester.pumpWidget(appShell(
      PanelSettingsScreen(restaurantId: 'r1', venue: _venue),
    ));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('rs_slot')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.byKey(const Key('rs_slot'))).dx, lessThan(64));

    // Tablet: the rules column moves beside the hours column.
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('rs_slot'))).dx,
      greaterThan(512),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('wh_open_sunday'))).dx,
      lessThan(400),
    );
  });

  testWidgets('renders in Arabic, with no raw translation key on screen',
      (tester) async {
    GetIt.instance.registerLazySingleton<SettingsPanelRepo>(
        () => _FakeSettingsRepo()..days = _week());
    addTearDown(GetIt.instance.reset);
    await tester.pumpWidget(appShell(
      PanelSettingsScreen(restaurantId: 'r1', venue: _venue),
      locale: const Locale('ar'),
    ));
    await pumpUntil(
      tester,
      () => find.byKey(const Key('rs_slot')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.text('ساعات العمل'), findsOneWidget);
    expect(find.text('إعدادات الحجوزات'), findsOneWidget);
    expect(find.text('المناسبات'), findsWidgets);

    // A missing Arabic key renders as `some_key` — never acceptable.
    final leakedKeys = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^[a-z][a-z0-9_]{4,}$').hasMatch(widget.data!),
    );
    expect(leakedKeys, findsNothing);
  });
}
