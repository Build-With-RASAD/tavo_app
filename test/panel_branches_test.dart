// test/panel_branches_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_branches/data/model/branch_models.dart';
import 'package:tavo/feature/panel_branches/data/repo/branches_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/branches_screen.dart';

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
  permissions: ['view_reports'],
  status: 'active',
);

Map<String, Map<String, dynamic>> _week() => {
      for (final d in ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri'])
        d: {'open': '09:00', 'close': '23:00', 'isClosed': false},
    };

PanelBranch _branch(String id, String en,
        {bool isMain = false, bool isActive = true}) =>
    PanelBranch(
      id: id,
      arName: 'فرع $id',
      enName: en,
      address: 'King Fahd Rd',
      city: 'Riyadh',
      region: 'Riyadh',
      phones: const ['+966501112233'],
      workingHours: _week(),
      isActive: isActive,
      isMain: isMain,
    );

class _FakeBranchesRepo extends BranchesPanelRepo {
  _FakeBranchesRepo() : super(api: ApiService());
  List<PanelBranch> branches = [];
  Object? failure;
  final List<String> calls = [];

  @override
  Future<List<PanelBranch>> getBranches(String restaurantId) async {
    calls.add('getBranches');
    _maybeThrow();
    return branches;
  }

  @override
  Future<PanelBranch> createBranch(
      {required String restaurantId,
      required String arName,
      required String enName,
      required String address,
      required String city,
      required String region,
      required List<String> phones,
      String? email,
      String? whatsapp,
      double? latitude,
      double? longitude,
      required Map<String, Map<String, dynamic>> workingHours,
      String? managerName}) async {
    calls.add('create:$enName:${workingHours.length}');
    final b = PanelBranch(
        id: 'b-new', arName: arName, enName: enName, address: address, city: city,
        region: region, phones: phones, email: email, whatsapp: whatsapp,
        latitude: latitude, longitude: longitude, workingHours: workingHours,
        managerName: managerName);
    branches = [...branches, b];
    return b;
  }

  @override
  Future<PanelBranch> updateBranch(
      {required String restaurantId,
      required String id,
      String? arName,
      String? enName,
      String? address,
      String? city,
      String? region,
      List<String>? phones,
      String? email,
      String? whatsapp,
      double? latitude,
      double? longitude,
      Map<String, Map<String, dynamic>>? workingHours,
      String? managerName,
      bool? isActive,
      bool? isMain}) async {
    calls.add('update:$id:${isActive ?? '-'}');
    final i = branches.indexWhere((b) => b.id == id);
    final o = branches[i];
    branches[i] = PanelBranch(
      id: o.id, arName: arName ?? o.arName, enName: enName ?? o.enName,
      address: address ?? o.address, city: city ?? o.city, region: region ?? o.region,
      phones: phones ?? o.phones, email: email ?? o.email, whatsapp: whatsapp ?? o.whatsapp,
      latitude: latitude ?? o.latitude, longitude: longitude ?? o.longitude,
      workingHours: workingHours ?? o.workingHours, managerName: managerName ?? o.managerName,
      displayOrder: o.displayOrder, isActive: isActive ?? o.isActive, isMain: isMain ?? o.isMain,
    );
    return branches[i];
  }

  @override
  Future<PanelBranch> deleteBranch(
      {required String restaurantId, required String id}) async {
    calls.add('delete:$id');
    return updateBranch(restaurantId: restaurantId, id: id, isActive: false);
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpBranches(WidgetTester tester, _FakeBranchesRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<BranchesPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(
      appShell(BranchesScreen(restaurantId: 'r1', venue: venue)));
  // Same amendment as panel_staff_test: EasyLocalization finishes loading
  // its translations asynchronously and a bare `pumpWidget` can exit before
  // the child subtree is built, so wait until the skeleton is in the tree
  // before the test body runs.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    await _pumpBranches(tester, _FakeBranchesRepo());
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('empty branches show the composed empty state',
      (tester) async {
    await _pumpBranches(tester, _FakeBranchesRepo());
    await tester.pumpAndSettle();
    expect(find.text('No branches yet'), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeBranchesRepo()..failure = Exception('boom');
    await _pumpBranches(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Iconsax.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'getBranches'), hasLength(2));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('No branches yet'), findsOneWidget);
  });

  testWidgets('list renders primary and inactive chips', (tester) async {
    final repo = _FakeBranchesRepo()
      ..branches = [
        _branch('b1', 'Riyadh Branch', isMain: true),
        _branch('b2', 'Old Branch', isActive: false),
      ];
    await _pumpBranches(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Riyadh Branch'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('add journals names plus the 7-day hours map', (tester) async {
    final repo = _FakeBranchesRepo();
    await _pumpBranches(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_branch')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('branch_name_ar')), 'فرع جديد');
    await tester.enterText(
        find.byKey(const Key('branch_name_en')), 'New Branch');
    await tester.enterText(
        find.byKey(const Key('branch_address')), 'King Fahd Rd');
    await tester.enterText(find.byKey(const Key('branch_city')), 'Riyadh');
    await tester.enterText(
        find.byKey(const Key('branch_region')), 'Riyadh');
    await tester.tap(find.byKey(const Key('save_branch')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('create:New Branch:7'));
    expect(find.text('New Branch'), findsOneWidget);
  });

  testWidgets('deactivate flips the row to inactive in place',
      (tester) async {
    final repo = _FakeBranchesRepo()
      ..branches = [_branch('b1', 'Riyadh Branch')];
    await _pumpBranches(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actions_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('update:b1:false'));
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('delete goes through the confirmation action sheet',
      (tester) async {
    final repo = _FakeBranchesRepo()
      ..branches = [_branch('b1', 'Riyadh Branch')];
    await _pumpBranches(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actions_b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('delete:b1'));
    expect(find.text('Inactive'), findsOneWidget); // soft delete stays listed
  });

  testWidgets('hides every mutation control from view-only staff',
      (tester) async {
    final repo = _FakeBranchesRepo()
      ..branches = [_branch('b1', 'Riyadh Branch')];
    await _pumpBranches(tester, repo, venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.text('Riyadh Branch'), findsOneWidget);
    expect(find.byKey(const Key('add_branch')), findsNothing);
    expect(find.byKey(const Key('actions_b1')), findsNothing);
  });
}
