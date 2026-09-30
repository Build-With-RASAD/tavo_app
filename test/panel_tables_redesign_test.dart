// test/panel_tables_redesign_test.dart — Wave E3 Task 28 (tables view redesign)
//
// Spec: docs/superpowers/specs/2026-09-30-tables-redesign.md — mode-based live
// floor (colors/sizing/legend/backdrops), detail sheet + actions, role gating,
// 0.05 snap math, CRUD through the fake repo, delete confirm, onOpenOrders,
// error+retry and the composed empty state.
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

const _ownerVenue = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

const _viewerVenue = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_tables'],
  status: 'active',
);

class _FakeTablesRepo extends TablesPanelRepo {
  _FakeTablesRepo() : super(api: ApiService());

  List<PanelTableType> types = [];
  List<PanelPhysicalTable> tables = [];
  bool failLoad = false;
  final List<String> calls = [];

  @override
  Future<List<PanelTableType>> getTableTypes(String restaurantId) async {
    if (failLoad) {
      failLoad = false; // retry recovers
      throw Exception('boom');
    }
    return types;
  }

  @override
  Future<List<PanelPhysicalTable>> getPhysicalTables(
      String restaurantId, String tableTypeId) async {
    calls.add('getPhysical:$tableTypeId');
    return tables.where((t) => t.tableTypeId == tableTypeId).toList();
  }

  @override
  Future<int> saveFloorPlan(String restaurantId,
      List<({String id, double? x, double? y})> positions) async {
    calls.add('saveFloor:${positions.length}');
    return positions.length;
  }

  @override
  Future<PanelPhysicalTable> updatePhysicalTableStatus(
      {required String restaurantId,
      required String id,
      required String status}) async {
    calls.add('status:$id:$status');
    final i = tables.indexWhere((t) => t.id == id);
    final t = tables[i];
    tables[i] = PanelPhysicalTable(
      id: t.id,
      tableTypeId: t.tableTypeId,
      code: t.code,
      seats: t.seats,
      status: status,
      zone: t.zone,
      occupied: t.occupied,
      x: t.x,
      y: t.y,
    );
    return tables[i];
  }

  @override
  Future<PanelPhysicalTable> createPhysicalTable({
    required String restaurantId,
    required String tableTypeId,
    required String code,
    required int seats,
    String? zone,
  }) async {
    calls.add('create:$tableTypeId:$code:$seats:${zone ?? 'null'}');
    final created = PanelPhysicalTable(
      id: 'new_$code',
      tableTypeId: tableTypeId,
      code: code,
      seats: seats,
      status: 'available',
      zone: zone,
    );
    tables = [...tables, created];
    return created;
  }

  @override
  Future<PanelPhysicalTable> updatePhysicalTable({
    required String restaurantId,
    required String id,
    String? code,
    int? seats,
    String? zone,
    bool clearZone = false,
  }) async {
    calls.add('update:$id:${code ?? '-'}:${seats ?? '-'}:'
        '${clearZone ? 'null' : (zone ?? '-')}');
    final i = tables.indexWhere((t) => t.id == id);
    final t = tables[i];
    tables[i] = PanelPhysicalTable(
      id: t.id,
      tableTypeId: t.tableTypeId,
      code: code ?? t.code,
      seats: seats ?? t.seats,
      status: t.status,
      zone: clearZone ? null : (zone ?? t.zone),
      occupied: t.occupied,
      x: t.x,
      y: t.y,
    );
    return tables[i];
  }

  @override
  Future<bool> deletePhysicalTable(
      {required String restaurantId, required String id}) async {
    calls.add('delete:$id');
    tables = tables.where((t) => t.id != id).toList();
    return true;
  }
}

PanelTableType _type({String id = 't1', String label = 'Indoor'}) =>
    PanelTableType(id: id, label: label, seatsPerTable: 4, tablesCount: 8);

Future<void> _pump(
  WidgetTester tester,
  _FakeTablesRepo repo, {
  StaffRestaurant venue = _ownerVenue,
  VoidCallback? onOpenOrders,
}) async {
  GetIt.instance.registerLazySingleton<TablesPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(TablesScreen(
    restaurantId: 'r1',
    venue: venue,
    onOpenOrders: onOpenOrders,
  )));
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
  await tester.pumpAndSettle();
}

Color _ringOf(WidgetTester tester, String id) {
  final card = tester.widget<Container>(find.byKey(Key('table_card_$id')));
  final decoration = card.decoration! as BoxDecoration;
  return (decoration.border as Border).top.color;
}

void main() {
  setUpAll(initTestEnv);

  testWidgets(
      'view mode (default) colors tables: occupied orange, reserved red, '
      'available green, inactive grey + 0.55 dimming', (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'reserved', occupied: true, x: 0.3, y: 0.3),
        const PanelPhysicalTable(
            id: 'p2', tableTypeId: 't1', code: 'IN-2', seats: 4,
            status: 'reserved', x: 0.6, y: 0.3),
        const PanelPhysicalTable(
            id: 'p3', tableTypeId: 't1', code: 'IN-3', seats: 4,
            status: 'available', x: 0.3, y: 0.7),
        const PanelPhysicalTable(
            id: 'p4', tableTypeId: 't1', code: 'IN-4', seats: 4,
            status: 'inactive', x: 0.6, y: 0.7),
      ];
    await _pump(tester, repo);

    // default mode is the view segment
    final viewChip = tester.widget<ChoiceChip>(find.byKey(const Key('mode_view')));
    expect(viewChip.selected, isTrue);

    expect(_ringOf(tester, 'p1'), Colors.orange); // occupied beats reserved
    expect(_ringOf(tester, 'p2'), Colors.red);
    expect(_ringOf(tester, 'p3'), Colors.green);
    expect(_ringOf(tester, 'p4'), Colors.grey);

    expect(
        tester.widget<Opacity>(find.byKey(const Key('dim_p4'))).opacity,
        0.55);
    expect(
        tester.widget<Opacity>(find.byKey(const Key('dim_p1'))).opacity, 1.0);
    // inactive tables are dimmed, never hidden
    expect(find.byKey(const Key('table_p4')), findsOneWidget);
  });

  testWidgets('sizes table cards by the seats buckets 44/52/64/76',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 's1', tableTypeId: 't1', code: 'S1', seats: 1,
            status: 'available', x: 0.2, y: 0.3),
        const PanelPhysicalTable(
            id: 's2', tableTypeId: 't1', code: 'S2', seats: 3,
            status: 'available', x: 0.5, y: 0.3),
        const PanelPhysicalTable(
            id: 's3', tableTypeId: 't1', code: 'S3', seats: 6,
            status: 'available', x: 0.2, y: 0.7),
        const PanelPhysicalTable(
            id: 's4', tableTypeId: 't1', code: 'S4', seats: 8,
            status: 'available', x: 0.6, y: 0.7),
      ];
    await _pump(tester, repo);

    expect(tester.getSize(find.byKey(const Key('table_s1'))).width, 44);
    expect(tester.getSize(find.byKey(const Key('table_s2'))).width, 52);
    expect(tester.getSize(find.byKey(const Key('table_s3'))).width, 64);
    expect(tester.getSize(find.byKey(const Key('table_s4'))).width, 76);
  });

  testWidgets('zone legend counts zones; backdrops only for positioned zones',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'z1', tableTypeId: 't1', code: 'Z1', seats: 4,
            status: 'available', zone: 'Indoor', x: 0.3, y: 0.3),
        const PanelPhysicalTable(
            id: 'z2', tableTypeId: 't1', code: 'Z2', seats: 4,
            status: 'available', zone: 'Indoor', x: 0.6, y: 0.6),
        const PanelPhysicalTable(
            id: 'z3', tableTypeId: 't1', code: 'Z3', seats: 4,
            status: 'available', zone: 'Garden'), // unpositioned → tray
      ];
    await _pump(tester, repo);

    expect(find.byKey(const Key('zone_legend')), findsOneWidget);
    expect(find.text('Indoor • 2'), findsOneWidget);
    expect(find.text('Garden • 1'), findsOneWidget);
    expect(find.byKey(const Key('zone_backdrop_Indoor')), findsOneWidget);
    expect(find.byKey(const Key('zone_backdrop_Garden')), findsNothing);
    expect(find.byKey(const Key('zone_backdrop_label_Garden')), findsNothing);
    expect(find.byKey(const Key('floor_tray')), findsOneWidget); // Z3 in tray
  });

  testWidgets('tap opens the detail sheet with edit/toggle/delete actions',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', zone: 'Indoor', x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('table_sheet')), findsOneWidget);
    expect(find.byKey(const Key('sheet_title')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('sheet_title'))).data,
        'IN-1'); // sheet title carries the code
    expect(find.byKey(const Key('sheet_edit')), findsOneWidget);
    expect(find.byKey(const Key('sheet_toggle')), findsOneWidget);
    expect(find.byKey(const Key('sheet_delete')), findsOneWidget);
    expect(find.byKey(const Key('sheet_zone')), findsOneWidget);
    expect(find.byKey(const Key('sheet_open_orders')), findsNothing);
  });

  testWidgets(
      'occupied sheet shows the hint and fires onOpenOrders (no start-order)',
      (tester) async {
    var opened = 0;
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', occupied: true, x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo, onOpenOrders: () => opened++);

    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sheet_occupied')), findsOneWidget);
    expect(find.byKey(const Key('sheet_open_orders')), findsOneWidget);
    expect(find.byKey(const Key('sheet_start_order')), findsNothing);

    await tester.tap(find.byKey(const Key('sheet_open_orders')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('view-only staff get no edit toggle, save, add or sheet actions',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo, venue: _viewerVenue);

    expect(find.byKey(const Key('mode_edit')), findsNothing);
    expect(find.byKey(const Key('mode_view')), findsNothing);
    expect(find.byKey(const Key('save_floor')), findsNothing);
    expect(find.byKey(const Key('add_table')), findsNothing);

    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('table_sheet')), findsOneWidget);
    expect(find.byKey(const Key('sheet_edit')), findsNothing);
    expect(find.byKey(const Key('sheet_toggle')), findsNothing);
    expect(find.byKey(const Key('sheet_delete')), findsNothing);
  });

  testWidgets('edit mode gates multi-select and bulk zone/status on the repo',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.3, y: 0.3),
        const PanelPhysicalTable(
            id: 'p2', tableTypeId: 't1', code: 'IN-2', seats: 4,
            status: 'available', x: 0.6, y: 0.3),
        const PanelPhysicalTable(
            id: 'p3', tableTypeId: 't1', code: 'IN-3', seats: 4,
            status: 'available', zone: 'Terrace', x: 0.6, y: 0.7),
      ];
    await _pump(tester, repo);

    expect(find.byKey(const Key('add_table')), findsNothing);
    expect(find.byKey(const Key('select_toggle')), findsNothing);

    await tester.tap(find.byKey(const Key('mode_edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_table')), findsOneWidget);
    expect(find.byKey(const Key('select_toggle')), findsOneWidget);
    expect(find.byKey(const Key('bulk_bar')), findsNothing);

    await tester.tap(find.byKey(const Key('select_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('table_p2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk_bar')), findsOneWidget);
    expect(find.byKey(const Key('selected_p1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bulk_zone_Terrace')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('update:p1:-:-:Terrace'));
    expect(repo.calls, contains('update:p2:-:-:Terrace'));

    await tester.tap(find.byKey(const Key('bulk_status_inactive')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('status:p1:inactive'));
    expect(repo.calls, contains('status:p2:inactive'));
  });

  testWidgets('delete flow asks for confirmation and only then hits the repo',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.4, y: 0.4),
        const PanelPhysicalTable(
            id: 'p2', tableTypeId: 't1', code: 'IN-2', seats: 4,
            status: 'available', x: 0.7, y: 0.7),
      ];
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet_delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete_confirm')), findsOneWidget);
    expect(repo.calls, isNot(contains('delete:p1')));

    await tester.tap(find.byKey(const Key('delete_confirm_no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('table_sheet')), findsOneWidget);
    expect(repo.calls, isNot(contains('delete:p1')));

    await tester.tap(find.byKey(const Key('sheet_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_confirm_yes')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('delete:p1'));
    expect(find.byKey(const Key('table_p1')), findsNothing);
    expect(find.byKey(const Key('table_p2')), findsOneWidget);
  });

  testWidgets('edit form posts code/seats/zone through updatePhysicalTable',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', zone: 'Indoor', x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('table_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet_edit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('form_submit')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form_code')), 'IN-9');
    await tester.enterText(find.byKey(const Key('form_seats')), '7');
    await tester.tap(find.byKey(const Key('form_submit')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('update:p1:IN-9:7:Indoor'));
  });

  testWidgets('add-table form creates through createPhysicalTable',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo);

    await tester.tap(find.byKey(const Key('mode_edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_table')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('form_code')), 'NEW-1');
    await tester.enterText(find.byKey(const Key('form_seats')), '2');
    await tester.tap(find.byKey(const Key('form_submit')));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('create:t1:NEW-1:2:null'));
  });

  test('CRUD cubit calls hit the fake repo with the right args', () async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', zone: 'Indoor'),
      ];
    final cubit = TablesPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.createTable(code: 'N1', seats: 5, zone: 'Terrace');
    var loaded = cubit.state as TablesPanelLoaded;
    expect(repo.calls, contains('create:t1:N1:5:Terrace'));
    expect(loaded.tables.map((t) => t.code), contains('N1'));

    await cubit.updateTable('p1', code: 'IN-1B', seats: 6, clearZone: true);
    loaded = cubit.state as TablesPanelLoaded;
    expect(repo.calls, contains('update:p1:IN-1B:6:null'));
    final updated = loaded.tables.firstWhere((t) => t.id == 'p1');
    expect(updated.code, 'IN-1B');
    expect(updated.seats, 6);
    expect(updated.zone, isNull);

    await cubit.deleteTable('p1');
    loaded = cubit.state as TablesPanelLoaded;
    expect(repo.calls, contains('delete:p1'));
    expect(loaded.tables.map((t) => t.id), isNot(contains('p1')));
  });

  test('snap math rounds to 0.05 steps and moveTable applies it', () {
    expect(TablesPanelCubit.snapToGrid(0.13), 0.15);
    expect(TablesPanelCubit.snapToGrid(0.07), 0.05);
    expect(TablesPanelCubit.snapToGrid(0.98), 1.0);
    expect(TablesPanelCubit.snapToGrid(0.02), 0.0);

    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.31, y: 0.62),
      ];
    final cubit = TablesPanelCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);

    cubit.moveTable('p1', 0.13, 0.97, snap: true);
    var loaded = cubit.state as TablesPanelLoaded;
    expect(loaded.tables.single.x, 0.15);
    expect(loaded.tables.single.y, 0.95);

    // free drag (view mode) keeps the raw value, clamped
    cubit.moveTable('p1', 9.9, -0.4);
    loaded = cubit.state as TablesPanelLoaded;
    expect(loaded.tables.single.x, 1.0);
    expect(loaded.tables.single.y, 0.0);
  });

  testWidgets('load failure shows the inline error and retry recovers',
      (tester) async {
    final repo = _FakeTablesRepo()
      ..types = [_type()]
      ..failLoad = true
      ..tables = [
        const PanelPhysicalTable(
            id: 'p1', tableTypeId: 't1', code: 'IN-1', seats: 4,
            status: 'available', x: 0.4, y: 0.4),
      ];
    await _pump(tester, repo);

    expect(find.text('boom'), findsOneWidget);
    expect(find.byType(ErrorStateView), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorStateView), findsNothing);
    expect(find.byKey(const Key('table_p1')), findsOneWidget);
  });

  testWidgets('empty types show the composed empty state', (tester) async {
    await _pump(tester, _FakeTablesRepo());
    expect(find.text('No tables yet'), findsOneWidget);
  });
}
