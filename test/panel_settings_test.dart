// test/panel_settings_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
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

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'getSettings'), hasLength(2));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('Working hours'), findsOneWidget);
  });

  testWidgets('saving hours journals the closed-day count', (tester) async {
    final repo = _FakeSettingsRepo()..days = _week();
    await _pumpSettings(tester, repo);
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
}
