// test/panel_menu_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/data/repo/menu_panel_repo.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';
import 'package:tavo/feature/panel_menu/ui/screens/panel_menu_screen.dart';

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

/// Read-only staff: the `requirePermission`-mirroring gate must hide mutations.
const _venueView = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_menu'],
  status: 'active',
);

PanelMenuCategory _cat(String id, String ar, String en, {int items = 0}) =>
    PanelMenuCategory(id: id, arName: ar, enName: en, itemCount: items);

PanelMenuItem _item(String id, String cat, String ar, String en, double price,
        {bool active = true}) =>
    PanelMenuItem(
        id: id, categoryId: cat, arName: ar, enName: en, price: price, active: active);

/// Fake repo: canned payloads + call journal. Every mutation journals its id.
///
/// Signatures mirror the real repo exactly (including the optional named
/// `restaurantId` on toggle/delete/create) so `@override` type-checks.
class _FakeRepo extends MenuPanelRepo {
  _FakeRepo() : super(api: ApiService());
  List<PanelMenuCategory> categories = [];
  List<PanelMenuItem> items = [];
  int page = 1;
  int pages = 1;
  Object? failure;
  final List<String> calls = [];

  @override
  Future<List<PanelMenuCategory>> getCategories(String restaurantId) async {
    calls.add('getCategories');
    _maybeThrow();
    return categories;
  }

  @override
  Future<({List<PanelMenuItem> items, int page, int pages, int total})>
      getItems(String restaurantId,
          {int page = 1, String? categoryId, String? status}) async {
    calls.add('getItems:$page:${categoryId ?? '*'}:${status ?? '*'}');
    _maybeThrow();
    var visible = categoryId == null
        ? items
        : items.where((i) => i.categoryId == categoryId).toList();
    if (status != null) {
      visible = visible
          .where((i) => (i.active ? 'active' : 'inactive') == status)
          .toList();
    }
    return (items: visible, page: page, pages: pages, total: visible.length);
  }

  @override
  Future<PanelMenuItem> toggleStatus(String id,
      {String? restaurantId}) async {
    calls.add('toggleStatus:$id');
    final i = items.indexWhere((e) => e.id == id);
    items[i] = PanelMenuItem(
      id: items[i].id,
      categoryId: items[i].categoryId,
      arName: items[i].arName,
      enName: items[i].enName,
      price: items[i].price,
      active: !items[i].active,
      imageUrl: items[i].imageUrl,
    );
    return items[i];
  }

  @override
  Future<void> deleteItem(String id, {String? restaurantId}) async {
    calls.add('deleteItem:$id');
    items.removeWhere((e) => e.id == id);
  }

  @override
  Future<PanelMenuItem> uploadItemImage(
      {required String restaurantId,
      required String id,
      required Uint8List bytes,
      required String filename}) async {
    calls.add('uploadItemImage:$id:$filename');
    _maybeThrow();
    final i = items.indexWhere((e) => e.id == id);
    items[i] = PanelMenuItem(
      id: items[i].id,
      categoryId: items[i].categoryId,
      arName: items[i].arName,
      enName: items[i].enName,
      price: items[i].price,
      active: items[i].active,
      imageUrl: 'https://cdn.test/$filename',
    );
    return items[i];
  }

  @override
  Future<PanelMenuItem> removeItemImage(
      {required String restaurantId, required String id}) async {
    calls.add('removeItemImage:$id');
    _maybeThrow();
    final i = items.indexWhere((e) => e.id == id);
    items[i] = PanelMenuItem(
      id: items[i].id,
      categoryId: items[i].categoryId,
      arName: items[i].arName,
      enName: items[i].enName,
      price: items[i].price,
      active: items[i].active,
      imageUrl: null,
    );
    return items[i];
  }

  @override
  Future<PanelMenuCategory> createCategory(
      {String? restaurantId,
      required String arName,
      required String enName}) async {
    calls.add('createCategory:$arName');
    final c = _cat('c-new', arName, enName);
    categories = [...categories, c];
    return c;
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

/// The screen builds its OWN cubit from get_it (mirroring
/// `DashboardScreen`), so the fake is injected as the repo registration and
/// role gating flows through the `venue` fixture.
///
/// Amendment: after `pumpWidget`, pumps until the skeleton is in the tree.
/// EasyLocalization finishes loading its translations asynchronously and a
/// bare `pumpAndSettle` can exit before the child subtree is built (see
/// `helpers/app_shell.dart`), so the loading assertion needs the skeleton
/// present before the test body runs.
Future<void> _pumpMenu(WidgetTester tester, _FakeRepo repo,
    {StaffRestaurant venue = _venue}) async {
  GetIt.instance.registerLazySingleton<MenuPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(PanelMenuScreen(
    restaurantId: 'r1',
    venue: venue,
    canManage: () =>
        venue.role == 'owner' ||
        venue.role == 'manager' ||
        venue.permissions.contains('full_access') ||
        venue.permissions.contains('manage_menu'),
  )));
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    final repo = _FakeRepo();
    await _pumpMenu(tester, repo);
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('empty menu shows the composed empty state', (tester) async {
    final repo = _FakeRepo();
    await _pumpMenu(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('No menu items yet'), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeRepo()..failure = Exception('boom');
    await _pumpMenu(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.calls, containsAll(['getCategories', 'getItems:1:*:*']));
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('renders items and toggles status through the row spinner',
      (tester) async {
    final repo = _FakeRepo()
      ..categories = [_cat('c1', 'برجر', 'Burgers')]
      ..items = [_item('m1', 'c1', 'دبل برجر', 'Double Burger', 32)];

    await _pumpMenu(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('Double Burger'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle_m1')));
    await tester.pump(); // spinner frame
    await tester.pumpAndSettle();

    expect(repo.calls, contains('toggleStatus:m1'));
    expect(find.text('Double Burger'), findsOneWidget); // row survived
    expect(find.text('Inactive'), findsOneWidget); // badge flipped
  });

  testWidgets('delete goes through the confirmation action sheet',
      (tester) async {
    final repo = _FakeRepo()
      ..categories = [_cat('c1', 'برجر', 'Burgers')]
      ..items = [_item('m1', 'c1', 'دبل برجر', 'Double Burger', 32)];

    await _pumpMenu(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_m1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete item'), findsOneWidget); // action sheet title
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('deleteItem:m1'));
    expect(find.text('Double Burger'), findsNothing);
    expect(find.text('No menu items yet'), findsOneWidget); // composed empty
  });

  testWidgets('hides every mutation control when the role cannot manage_menu',
      (tester) async {
    final repo = _FakeRepo()
      ..categories = [_cat('c1', 'برجر', 'Burgers')]
      ..items = [_item('m1', 'c1', 'دبل برجر', 'Double Burger', 32)];

    await _pumpMenu(tester, repo, venue: _venueView);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_item')), findsNothing);
    expect(find.byKey(const Key('delete_m1')), findsNothing);
    expect(find.byKey(const Key('toggle_m1')), findsNothing);
    expect(find.byKey(const Key('add_photo_m1')), findsNothing);
    expect(find.text('Double Burger'), findsOneWidget); // read path intact
  });

  testWidgets('status chips refetch through the server-side status filter',
      (tester) async {
    final repo = _FakeRepo()
      ..categories = [_cat('c1', 'برجر', 'Burgers')]
      ..items = [
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28, active: false),
        ];

    await _pumpMenu(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Double Burger'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter_inactive')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('getItems:1:*:inactive'));
    expect(find.text('Cheese Burger'), findsOneWidget);
    expect(find.text('Double Burger'), findsNothing);

    await tester.tap(find.byKey(const Key('filter_all')));
    await tester.pumpAndSettle();
    expect(find.text('Double Burger'), findsOneWidget); // back to all
  });

  test('uploadImage routes bytes to the image endpoint and swaps the row',
      () async {
    final repo = _FakeRepo()
      ..categories = [_cat('c1', 'برجر', 'Burgers')]
      ..items = [_item('m1', 'c1', 'دبل برجر', 'Double Burger', 32)];
    final cubit =
        PanelMenuCubit(repo, restaurantId: 'r1', canManage: () => true);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.uploadImage('m1', Uint8List.fromList([1, 2, 3]), 'burger.png');

    expect(repo.calls, contains('uploadItemImage:m1:burger.png'));
    final loaded = cubit.state as PanelMenuLoaded;
    expect(loaded.items.single.imageUrl, 'https://cdn.test/burger.png');
    expect(loaded.actionId, isNull); // spinner cleared
  });
}
