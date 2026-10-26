// test/panel_tables_redesign_test.dart
//
// Widget contract for the floor control room: role gating, the today strip,
// the attention rail, floor/list switching, the table sheet (QR, asks, bill,
// settle), delete confirmation, onOpenOrders, error+retry, and the empty
// floor. Money is always "sales", never profit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_tables/data/model/floor_models.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/screens/table_qr_batch_screen.dart';
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

Map<String, dynamic> _request({
  String id = 'req1',
  String type = 'bill',
  String createdAt = '2026-10-26T12:00:00.000Z',
}) =>
    {
      'id': id,
      'type': type,
      'guestLabel': 'Guest 2',
      'createdAt': createdAt,
    };

Map<String, dynamic> _session({
  String id = 's1',
  String code = 'HYJQ',
  int guests = 2,
  double total = 133.40,
  double paid = 0,
  List<Map<String, dynamic>> requests = const [],
}) =>
    {
      'id': id,
      '_id': id,
      'code': code,
      'status': 'open',
      'guests': guests,
      'subtotal': total - 13.4,
      'tax': 13.4,
      'total': total,
      'paid': paid,
      'pendingRequests': requests.length,
      'requests': requests,
      'openedAt': '2026-10-26T10:30:00.000Z',
    };

Map<String, dynamic> _table({
  required String id,
  required String code,
  String status = 'available',
  String displayStatus = 'available',
  String? zone = 'Indoor',
  int seats = 4,
  Map<String, dynamic>? session,
  List<Map<String, dynamic>> orders = const [],
  Map<String, dynamic>? reservation,
  List<Map<String, dynamic>> requests = const [],
  double? x,
  double? y,
}) =>
    {
      '_id': id,
      'id': id,
      'code': code,
      'seats': seats,
      'status': status,
      'displayStatus': displayStatus,
      'zone': zone,
      'tableTypeId': {'_id': 'type1', 'label': 'Indoor'},
      'position': x == null ? null : {'x': x, 'y': y},
      'session': session,
      'orders': orders,
      'reservation': reservation,
      'pendingRequests': requests,
      'occupied': displayStatus == 'occupied',
    };

Map<String, dynamic> _floor({
  List<Map<String, dynamic>>? tables,
  List<Map<String, dynamic>>? reservations,
  List<Map<String, dynamic>>? types,
}) =>
    {
      'kpi': {
        'salesToday': 1250.5,
        'ordersToday': 12,
        'avgTicket': 104.21,
        'openBills': 1,
        'openBillsTotal': 133.4,
        'occupiedTables': 1,
        'totalTables': 3,
        'occupancyPct': 33,
        'reservationsToday': 2,
        'seatedNow': 2,
        'nextReservationAt': '2026-10-26T19:30:00.000Z',
        'waitlistCount': 0,
      },
      'types': types ??
          [
            {
              'id': 'type1',
              'label': 'Indoor',
              'seatsPerTable': 4,
              'tablesCount': 3,
            },
          ],
      'tables': tables ??
          [
            _table(
              id: 't1',
              code: 'T1-1',
              displayStatus: 'occupied',
              session: _session(requests: [_request()]),
              orders: [
                {
                  'id': 'o1',
                  'orderNumber': 'ORD-7212',
                  'status': 'preparing',
                  'totalPrice': 133.40,
                  'subtotal': 120,
                  'tax': 13.4,
                  'itemCount': 2,
                  'note': 'Allergy: nuts',
                  'items': [
                    {
                      'name': 'Chicken Kabsa',
                      'nameAr': 'كبسة دجاج',
                      'quantity': 2,
                      'unitPrice': 60,
                      'lineTotal': 120,
                      'note': 'Extra saffron',
                      'specifications': [
                        {'name': 'Saffron rice', 'price': 0},
                      ],
                    },
                  ],
                },
              ],
              x: 0.3,
              y: 0.35,
            ),
            _table(id: 't2', code: 'T1-2', x: 0.7, y: 0.35),
            _table(
              id: 't3',
              code: 'T2-1',
              status: 'reserved',
              displayStatus: 'reserved',
              zone: 'Terrace',
              reservation: {
                'id': 'res1',
                'startAt': '2026-10-26T19:30:00.000Z',
                'guestsCount': 4,
                'status': 'confirmed',
                'customerName': 'Sara',
                'customerPhone': '0550000000',
                'tableIds': ['t3'],
              },
              x: 0.3,
              y: 0.75,
            ),
          ],
      'reservations': reservations ??
          [
            {
              'id': 'res1',
              'startAt': '2026-10-26T19:30:00.000Z',
              'guestsCount': 4,
              'status': 'confirmed',
              'customerName': 'Sara',
              'customerPhone': '0550000000',
              'tableIds': ['t3'],
            },
          ],
      'generatedAt': '2026-10-26T12:00:00.000Z',
    };

class _FakeTablesRepo extends TablesPanelRepo {
  _FakeTablesRepo({Map<String, dynamic>? floor})
      : floor = floor ?? _floor(),
        super(api: ApiService());

  Map<String, dynamic> floor;
  bool failNextLoad = false;
  final List<String> calls = [];

  List<Map<String, dynamic>> get _tables =>
      (floor['tables'] as List).cast<Map<String, dynamic>>();

  @override
  Future<PanelFloorSnapshot> getFloor(String restaurantId) async {
    calls.add('getFloor');
    if (failNextLoad) {
      failNextLoad = false;
      throw Exception('The floor could not be loaded');
    }
    return PanelFloorSnapshot.fromJson(floor);
  }

  @override
  Future<PanelSessionSummary> handleServiceRequest({
    required String restaurantId,
    required String tableId,
    required String requestId,
  }) async {
    calls.add('handle:$tableId:$requestId');
    for (final table in _tables) {
      if (table['id'] != tableId) continue;
      table['pendingRequests'] = <Map<String, dynamic>>[];
      final session = table['session'];
      if (session is Map) {
        session['requests'] = <Map<String, dynamic>>[];
        session['pendingRequests'] = 0;
      }
    }
    return PanelSessionSummary.fromJson(
      _session(requests: const <Map<String, dynamic>>[]),
    );
  }

  @override
  Future<PanelSessionSummary> settleTable({
    required String restaurantId,
    required String id,
    double? amount,
  }) async {
    calls.add('settle:$id');
    for (final table in _tables) {
      if (table['id'] != id) continue;
      table['session'] = null;
      table['orders'] = <Map<String, dynamic>>[];
      table['displayStatus'] = 'available';
      table['occupied'] = false;
    }
    return PanelSessionSummary.fromJson(_session(paid: 133.40));
  }

  @override
  Future<bool> deletePhysicalTable({
    required String restaurantId,
    required String id,
  }) async {
    calls.add('delete:$id');
    floor['tables'] = [
      for (final table in _tables)
        if (table['id'] != id) table,
    ];
    return true;
  }

  @override
  Future<PanelPhysicalTable> updatePhysicalTableStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    calls.add('status:$id:$status');
    return PanelPhysicalTable.fromJson(_table(id: id, code: 'T1-1'));
  }

  @override
  Future<PanelPhysicalTable> createPhysicalTable({
    required String restaurantId,
    required String tableTypeId,
    required String code,
    required int seats,
    String? zone,
  }) async {
    calls.add('create:$code');
    return PanelPhysicalTable.fromJson(_table(id: 'new', code: code));
  }

  @override
  Future<int> saveFloorPlan(
    String restaurantId,
    List<({String id, double? x, double? y})> rows,
  ) async {
    calls.add('saveFloor:${rows.length}');
    return rows.length;
  }

  @override
  Future<PanelTableQr> getTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    calls.add('qr:$tableId');
    return PanelTableQr(
      tableId: tableId,
      code: 'T1-1',
      url: 'https://tavo.abwabdigital.com/t/token-$tableId-v1',
      version: 1,
    );
  }

  @override
  Future<PanelTableQr> rotateTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    calls.add('rotate:$tableId');
    return PanelTableQr(
      tableId: tableId,
      code: 'T1-1',
      url: 'https://tavo.abwabdigital.com/t/token-$tableId-v2',
      version: 2,
    );
  }

  @override
  Future<void> reservationAction({
    required String restaurantId,
    required String id,
    required String action,
  }) async {
    calls.add('reservation:$id:$action');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeTablesRepo repo, {
  StaffRestaurant venue = _ownerVenue,
  VoidCallback? onOpenOrders,
}) async {
  // The screen is laid out for a phone; keep ScreenUtil's `.w/.h/.sp` in the
  // same ratio the app ships with so rail heights and type stay coherent.
  tester.view.physicalSize = const Size(400, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  GetIt.instance.registerLazySingleton<TablesPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(TablesScreen(
    restaurantId: 'r1',
    venue: venue,
    onOpenOrders: onOpenOrders,
    autoRefresh: false,
  )));
  await pumpUntil(
    tester,
    () =>
        find.byKey(const Key('tables_scroll')).evaluate().isNotEmpty ||
        find.byType(ErrorStateView).evaluate().isNotEmpty ||
        find.text('No tables yet').evaluate().isNotEmpty,
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view inside the nearest scrollable, then taps it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('owner sees the control room: today strip, rails and tools',
      (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    expect(find.text('Live floor'), findsOneWidget);
    expect(find.text('1250.50 SAR'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.byKey(const Key('today_strip')), findsOneWidget);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.byKey(const Key('attention_rail')), findsOneWidget);
    expect(find.byKey(const Key('reservations_rail')), findsOneWidget);
    expect(find.byKey(const Key('floor_canvas')), findsOneWidget);

    expect(find.byKey(const Key('add_table')), findsOneWidget);
    expect(find.byKey(const Key('arrange_mode')), findsOneWidget);
    expect(find.byKey(const Key('select_tables')), findsOneWidget);
    expect(find.byKey(const Key('batch_qr')), findsOneWidget);
  });

  testWidgets('read-only staff get no edit, arrange, add or bulk affordances',
      (tester) async {
    await _pump(tester, _FakeTablesRepo(), venue: _viewerVenue);

    expect(find.byKey(const Key('add_table')), findsNothing);
    expect(find.byKey(const Key('arrange_mode')), findsNothing);
    expect(find.byKey(const Key('select_tables')), findsNothing);
    expect(find.byKey(const Key('batch_qr')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('floor_t1')));
    expect(find.byKey(const Key('edit_table')), findsNothing);
    expect(find.byKey(const Key('delete_table')), findsNothing);
  });

  testWidgets('handling a guest ask clears it from the rail and the card',
      (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('handle_req1')));

    expect(repo.calls, contains('handle:t1:req1'));
    expect(find.byKey(const Key('attention_rail')), findsNothing);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('floor/list switch renders dense rows, filters and search',
      (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('view_list')));
    expect(find.byKey(const Key('table_row_t1')), findsOneWidget);
    expect(find.byKey(const Key('table_row_t2')), findsOneWidget);
    expect(find.byKey(const Key('floor_canvas')), findsNothing);

    // Search is a real filter, not decoration.
    await tester.enterText(
      find.byKey(const Key('table_search')),
      'sara',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('table_row_t1')), findsNothing);
    expect(find.byKey(const Key('table_row_t3')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('clear_search')));
    expect(find.byKey(const Key('table_row_t1')), findsOneWidget);
  });

  testWidgets('the sheet shows the QR, the live ticket, the note and the bill',
      (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('floor_t1')));

    expect(find.byKey(const Key('table_qr_image')), findsOneWidget);
    expect(find.text('HYJQ'), findsOneWidget);
    expect(find.text('ORD-7212'), findsOneWidget);
    expect(find.text('Chicken Kabsa'), findsOneWidget);
    expect(find.text('Extra saffron'), findsOneWidget);
    expect(find.textContaining('Allergy: nuts'), findsOneWidget);
    expect(find.text('133.40 SAR'), findsWidgets);
    expect(find.byKey(const Key('settle_table')), findsOneWidget);
  });

  testWidgets('settling confirms, calls the cash endpoint and closes the sheet',
      (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('floor_t1')));
    await _tapVisible(tester, find.byKey(const Key('settle_table')));

    expect(find.textContaining('Record the bill as collected?'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('confirm_settle')));

    expect(repo.calls, contains('settle:t1'));
    expect(find.byKey(const Key('table_qr_image')), findsNothing);
    expect(find.byKey(const Key('floor_t1')), findsOneWidget);
  });

  testWidgets('delete asks first, then removes the table', (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('floor_t2')));
    await _tapVisible(tester, find.byKey(const Key('delete_table')));

    expect(find.text('Delete this table?'), findsOneWidget);
    expect(repo.calls, isNot(contains('delete:t2')));

    await _tapVisible(tester, find.byKey(const Key('confirm_delete_table')));
    expect(repo.calls, contains('delete:t2'));
    expect(find.byKey(const Key('floor_t2')), findsNothing);
  });

  testWidgets('open orders is offered from the sheet when the shell wires it',
      (tester) async {
    var opened = false;
    await _pump(tester, _FakeTablesRepo(), onOpenOrders: () => opened = true);

    await _tapVisible(tester, find.byKey(const Key('floor_t1')));
    await _tapVisible(tester, find.byKey(const Key('open_orders')));

    expect(opened, isTrue);
  });

  testWidgets('batch QR screen loads one card per table', (tester) async {
    final repo = _FakeTablesRepo();
    await _pump(tester, repo);

    await _tapVisible(tester, find.byKey(const Key('batch_qr')));

    expect(find.byType(TableQrBatchScreen), findsOneWidget);
    expect(find.byKey(const Key('qr_batch_grid')), findsOneWidget);
    expect(find.byKey(const Key('qr_card_t1')), findsOneWidget);
    expect(find.byKey(const Key('qr_card_t2')), findsOneWidget);
    expect(find.byKey(const Key('print_all_qr')), findsOneWidget);
    expect(repo.calls, contains('qr:t1'));
    expect(repo.calls, contains('qr:t2'));
  });

  testWidgets('empty floor explains the next step and offers add', (tester) async {
    final repo = _FakeTablesRepo(
      floor: _floor(tables: [], reservations: []),
    );
    await _pump(tester, repo);

    expect(find.text('No tables yet'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_table')), findsOneWidget);
  });

  testWidgets('error state retries into the floor', (tester) async {
    final repo = _FakeTablesRepo()..failNextLoad = true;
    await _pump(tester, repo);

    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text('The floor could not be loaded'), findsOneWidget);

    await _tapVisible(tester, find.text('Retry'));

    expect(find.byType(ErrorStateView), findsNothing);
    expect(find.byKey(const Key('floor_canvas')), findsOneWidget);
  });
}
