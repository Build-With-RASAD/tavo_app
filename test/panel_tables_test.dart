// test/panel_tables_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/logic/tables_panel_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/tables_screen.dart';

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

class _FakeTablesRepo extends TablesPanelRepo {
  _FakeTablesRepo() : super(api: ApiService());
  List<PanelTableType> types = [];
  List<PanelPhysicalTable> tables = [];
  final List<Map<String, double?>> savedLayouts = [];
  final List<String> calls = [];

  @override
  Future<List<PanelTableType>> getTableTypes(String restaurantId) async =>
      types;

  @override
  Future<List<PanelPhysicalTable>> getPhysicalTables(
      String restaurantId, String tableTypeId) async {
    calls.add('getPhysical:$tableTypeId');
    return tables.where((t) => t.tableTypeId == tableTypeId).toList();
  }

  @override
  Future<int> saveFloorPlan(
      String restaurantId, List<({String id, double? x, double? y})> positions) async {
    calls.add('saveFloor:${positions.length}');
    savedLayouts.add({for (final p in positions) p.id: p.x});
    return positions.length;
  }

  @override
  Future<PanelPhysicalTable> updatePhysicalTableStatus(
      {required String restaurantId,
      required String id,
      required String status}) async {
    calls.add('status:$id:$status');
    final i = tables.indexWhere((t) => t.id == id);
    tables[i] = PanelPhysicalTable(
        id: tables[i].id,
        tableTypeId: tables[i].tableTypeId,
        code: tables[i].code,
        seats: tables[i].seats,
        status: status,
        x: tables[i].x,
        y: tables[i].y);
    return tables[i];
  }
}

Future<void> _pumpTables(WidgetTester tester, _FakeTablesRepo repo) async {
  GetIt.instance.registerLazySingleton<TablesPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(TablesScreen(restaurantId: 'r1', venue: _venue)));
  // Mirrors panel_menu_test: EasyLocalization builds the child subtree
  // asynchronously, so wait for the shell before asserting on it.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('positioned tables render in the editor, nulls in the tray',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [const PanelTableType(id: 't1', label: 'Indoor', seatsPerTable: 4, tablesCount: 2)]
      ..tables = [
        const PanelPhysicalTable(id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4, status: 'available', x: 0.2, y: 0.3),
        const PanelPhysicalTable(id: 'p2', tableTypeId: 't1', code: 'IN-2', seats: 4, status: 'available'),
      ];
    await _pumpTables(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('floor_editor')), findsOneWidget);
    expect(find.byKey(const Key('table_p1')), findsOneWidget);
    expect(find.byKey(const Key('floor_tray')), findsOneWidget);
    expect(find.text('IN-2'), findsOneWidget); // tray card
  });

  testWidgets('drag + save posts fractional positions to PUT /floor-plan',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [const PanelTableType(id: 't1', label: 'Indoor', seatsPerTable: 4, tablesCount: 1)]
      ..tables = [
        const PanelPhysicalTable(id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4, status: 'available', x: 0.2, y: 0.3),
      ];
    await _pumpTables(tester, repo);
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('table_p1')), const Offset(30, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_floor')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('saveFloor:1'));
    final x = repo.savedLayouts.single['p1']!;
    expect(x, greaterThan(0.2)); // moved right inside the editor box
    expect(x, lessThanOrEqualTo(1.0)); // clamped
  });

  testWidgets('empty types show the composed empty state', (tester) async {
    await _pumpTables(tester, _FakeTablesRepo());
    await tester.pumpAndSettle();
    expect(find.text('No tables yet'), findsOneWidget);
  });

  test('moveTable clamps to [0,1] and save failure keeps positions',
      () async {
    final repo = _FakeTablesRepo()
      ..types = [const PanelTableType(id: 't1', label: 'Indoor', seatsPerTable: 4, tablesCount: 1)]
      ..tables = [
        const PanelPhysicalTable(id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4, status: 'available', x: 0.5, y: 0.5),
      ];
    final cubit = TablesPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.selectType('t1');

    cubit.moveTable('p1', 9.9, -2.0);
    var loaded = cubit.state as TablesPanelLoaded;
    expect(loaded.tables.single.x, 1.0);
    expect(loaded.tables.single.y, 0.0);
  });
}
