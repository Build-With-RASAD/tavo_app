// test/panel_staff_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_staff/data/model/staff_models.dart';
import 'package:tavo/feature/panel_staff/data/repo/staff_panel_repo.dart';
import 'package:tavo/feature/panel_staff/ui/logic/staff_panel_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/staff_screen.dart';

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

PanelStaffMember _member(String id, String name,
        {String status = 'active',
        List<String> permissions = const ['view_orders']}) =>
    PanelStaffMember(
        id: id,
        userId: 'u-$id',
        name: name,
        phone: '+966500000001',
        role: 'staff',
        permissions: permissions,
        status: status);

class _FakeStaffRepo extends StaffPanelRepo {
  _FakeStaffRepo() : super(api: ApiService());
  List<PanelStaffMember> members = [];
  Set<String> knownPhones = {};
  Object? failure;
  final List<String> calls = [];

  @override
  Future<List<PanelStaffMember>> getStaff(String restaurantId) async {
    calls.add('getStaff');
    _maybeThrow();
    return members;
  }

  @override
  Future<PanelStaffMember> addStaff(
      {required String restaurantId,
      required String phone,
      required String name,
      required String role,
      required List<String> permissions}) async {
    calls.add('add:$phone:$role:${permissions.length}');
    if (!knownPhones.contains(phone)) throw Exception('User not found');
    final m = PanelStaffMember(
        id: 's-new', userId: 'u-new', name: name, phone: phone, role: role, permissions: permissions, status: 'active');
    members = [...members, m];
    return m;
  }

  @override
  Future<PanelStaffMember> updateStaff(
      {required String restaurantId,
      required String id,
      String? role,
      List<String>? permissions,
      String? status}) async {
    calls.add('update:$id:${status ?? '-'}');
    final i = members.indexWhere((m) => m.id == id);
    var m = members[i];
    m = PanelStaffMember(
        id: m.id, userId: m.userId, name: m.name, phone: m.phone, email: m.email,
        role: role ?? m.role, permissions: permissions ?? m.permissions,
        status: status ?? m.status);
    // suspended members vanish from the backend list — mirror it
    members = status == 'suspended'
        ? members.where((e) => e.id != id).toList()
        : [for (final e in members) if (e.id == id) m else e];
    return m;
  }

  @override
  Future<void> deleteStaff(
      {required String restaurantId, required String id}) async {
    calls.add('delete:$id');
    members = members.where((m) => m.id != id).toList();
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpStaff(WidgetTester tester, _FakeStaffRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<StaffPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(StaffScreen(restaurantId: 'r1', venue: venue)));
  // Same amendment as panel_menu_test: EasyLocalization finishes loading
  // its translations asynchronously and a bare `pumpAndSettle` can exit
  // before the child subtree is built, so wait until the skeleton is in
  // the tree before the test body runs.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    await _pumpStaff(tester, _FakeStaffRepo());
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('empty staff shows the composed empty state', (tester) async {
    await _pumpStaff(tester, _FakeStaffRepo());
    await tester.pumpAndSettle();
    expect(find.text('No staff yet'), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeStaffRepo()..failure = Exception('boom');
    await _pumpStaff(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'getStaff'), hasLength(2));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('No staff yet'), findsOneWidget);
  });

  testWidgets('suspend removes the row (backend excludes suspended)',
      (tester) async {
    final repo = _FakeStaffRepo()..members = [_member('s1', 'Khaled')];
    await _pumpStaff(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Khaled'), findsOneWidget);

    await tester.tap(find.byKey(const Key('actions_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('update:s1:suspended'));
    expect(find.text('Khaled'), findsNothing);
  });

  testWidgets('delete goes through the confirmation action sheet',
      (tester) async {
    final repo = _FakeStaffRepo()..members = [_member('s1', 'Khaled')];
    await _pumpStaff(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actions_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete staff'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this staff member?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('delete:s1'));
    expect(find.text('Khaled'), findsNothing);
  });

  testWidgets('add sheet journals phone, role and permission count',
      (tester) async {
    final repo = _FakeStaffRepo()..knownPhones = {'+966500000001'};
    await _pumpStaff(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_staff')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('staff_name')), 'Khaled');
    await tester.enterText(
        find.byKey(const Key('staff_phone')), '+966500000001');
    await tester.tap(find.byKey(const Key('perm_full_access_shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_staff')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('add:+966500000001:staff:14'));
    expect(find.text('Khaled'), findsOneWidget);
  });

  testWidgets('hides every mutation control from view-only staff',
      (tester) async {
    final repo = _FakeStaffRepo()..members = [_member('s1', 'Khaled')];
    await _pumpStaff(tester, repo, venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.text('Khaled'), findsOneWidget);
    expect(find.byKey(const Key('add_staff')), findsNothing);
    expect(find.byKey(const Key('actions_s1')), findsNothing);
  });

  test('add with an unknown phone surfaces the backend error', () async {
    final repo = _FakeStaffRepo();
    final cubit = StaffPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.addStaff(
        phone: '+966500000009', name: 'Ghost', role: 'staff', permissions: const []);

    final loaded = cubit.state as StaffPanelLoaded;
    expect(loaded.members, isEmpty);
    expect(loaded.actionError, contains('User not found'));
  });
}
