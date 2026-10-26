// test/panel_tables_test.dart
//
// Contract tests for the floor control room's data layer. The screen is only
// as honest as these: one aggregate read, server-authoritative status, real
// request handling, idempotent QR reads, and destructive QR rotation.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_tables/data/model/floor_models.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_tables/data/repo/tables_panel_repo.dart';
import 'package:tavo/feature/panel_tables/ui/logic/tables_panel_cubit.dart';

Map<String, dynamic> _tableJson({
  required String id,
  String code = 'T1',
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
      'position': x == null || y == null ? null : {'x': x, 'y': y},
      'session': session,
      'orders': orders,
      'reservation': reservation,
      'pendingRequests': requests,
      'occupied': displayStatus == 'occupied',
    };

Map<String, dynamic> _sessionJson({
  String id = 's1',
  String code = 'ABC123',
  int guests = 2,
  double total = 120,
  double paid = 0,
  List<Map<String, dynamic>> requests = const [],
}) =>
    {
      'id': id,
      '_id': id,
      'code': code,
      'status': 'open',
      'guests': guests,
      'subtotal': total - 10,
      'tax': 10,
      'total': total,
      'paid': paid,
      'pendingRequests': requests.length,
      'requests': requests,
      'openedAt': '2026-10-26T10:00:00.000Z',
    };

Map<String, dynamic> _requestJson({
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

Map<String, dynamic> _floorJson({
  List<Map<String, dynamic>>? tables,
  List<Map<String, dynamic>>? reservations,
}) =>
    {
      'kpi': {
        'salesToday': 1250.5,
        'ordersToday': 12,
        'avgTicket': 104.21,
        'openBills': 2,
        'openBillsTotal': 240,
        'occupiedTables': 2,
        'totalTables': 6,
        'occupancyPct': 33,
        'reservationsToday': 3,
        'seatedNow': 5,
        'nextReservationAt': '2026-10-26T19:30:00.000Z',
      },
      'types': [
        {
          'id': 'type1',
          'label': 'Indoor',
          'seatsPerTable': 4,
          'tablesCount': 6,
        },
      ],
      'tables': tables ??
          [
            _tableJson(
              id: 't1',
              code: 'T1-1',
              displayStatus: 'occupied',
              session: _sessionJson(requests: [_requestJson()]),
              orders: [
                {
                  'id': 'o1',
                  'orderNumber': 'ORD-1',
                  'status': 'preparing',
                  'totalPrice': 120,
                  'subtotal': 110,
                  'tax': 10,
                  'itemCount': 2,
                  'items': [
                    {
                      'name': 'Chicken Kabsa',
                      'nameAr': 'كبسة دجاج',
                      'quantity': 2,
                      'unitPrice': 55,
                      'lineTotal': 110,
                      'note': 'No nuts',
                      'specifications': [
                        {'name': 'Saffron rice', 'price': 4},
                      ],
                    },
                  ],
                },
              ],
              x: 0.3,
              y: 0.4,
            ),
            _tableJson(id: 't2', code: 'T1-2'),
            _tableJson(
              id: 't3',
              code: 'T2-1',
              zone: 'Terrace',
              status: 'reserved',
              displayStatus: 'reserved',
              reservation: {
                'id': 'res1',
                'startAt': '2026-10-26T19:30:00.000Z',
                'guestsCount': 4,
                'status': 'confirmed',
                'customerName': 'Sara',
                'customerPhone': '0550000000',
                'tableIds': ['t3'],
              },
            ),
            _tableJson(
              id: 't4',
              code: 'T2-2',
              zone: 'Terrace',
              status: 'inactive',
              displayStatus: 'inactive',
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
            {
              'id': 'res2',
              'startAt': '2026-10-26T13:00:00.000Z',
              'guestsCount': 2,
              'status': 'pending',
              'customerName': 'Omar',
              'customerPhone': '0551111111',
              'tableIds': ['t2'],
            },
          ],
      'generatedAt': '2026-10-26T12:00:00.000Z',
    };

class _FakeTablesRepo extends TablesPanelRepo {
  _FakeTablesRepo() : super(api: ApiService());

  Map<String, dynamic> floor = _floorJson();
  Object? floorError;
  Object? saveError;
  Object? handleError;

  final List<String> calls = [];
  final List<List<({String id, double? x, double? y})>> savedLayouts = [];

  @override
  Future<PanelFloorSnapshot> getFloor(String restaurantId) async {
    calls.add('getFloor');
    if (floorError != null) throw floorError!;
    return PanelFloorSnapshot.fromJson(floor);
  }

  @override
  Future<int> saveFloorPlan(
    String restaurantId,
    List<({String id, double? x, double? y})> positions,
  ) async {
    calls.add('saveFloor:${positions.length}');
    if (saveError != null) throw saveError!;
    savedLayouts.add(positions);
    return positions.length;
  }

  @override
  Future<PanelPhysicalTable> updatePhysicalTableStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    calls.add('status:$id:$status');
    return PanelPhysicalTable.fromJson(
      _tableJson(id: id, code: 'T1-1', status: status, displayStatus: status),
    );
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
    calls.add('update:$id');
    return PanelPhysicalTable.fromJson(
      _tableJson(
        id: id,
        code: code ?? 'T1-1',
        seats: seats ?? 4,
        zone: clearZone ? null : (zone ?? 'Indoor'),
      ),
    );
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
    return PanelPhysicalTable.fromJson(
      _tableJson(id: 'new', code: code, seats: seats, zone: zone),
    );
  }

  @override
  Future<bool> deletePhysicalTable({
    required String restaurantId,
    required String id,
  }) async {
    calls.add('delete:$id');
    return true;
  }

  @override
  Future<PanelSessionSummary> handleServiceRequest({
    required String restaurantId,
    required String tableId,
    required String requestId,
  }) async {
    calls.add('handle:$tableId:$requestId');
    if (handleError != null) throw handleError!;
    floor = _floorJson(
      tables: [
        _tableJson(id: 't1', code: 'T1-1', displayStatus: 'occupied',
            session: _sessionJson(requests: const [])),
        _tableJson(id: 't2', code: 'T1-2'),
      ],
    );
    return PanelSessionSummary.fromJson(_sessionJson());
  }

  @override
  Future<PanelSessionSummary> settleTable({
    required String restaurantId,
    required String id,
    double? amount,
  }) async {
    calls.add('settle:$id:${amount ?? 'all'}');
    floor = _floorJson(
      tables: [
        _tableJson(id: 't1', code: 'T1-1'),
        _tableJson(id: 't2', code: 'T1-2'),
      ],
    );
    return PanelSessionSummary.fromJson(_sessionJson(paid: 120));
  }

  @override
  Future<void> reservationAction({
    required String restaurantId,
    required String id,
    required String action,
  }) async {
    calls.add('reservation:$id:$action');
  }

  int qrReads = 0;
  int qrRotates = 0;

  @override
  Future<PanelTableQr> getTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    calls.add('qr:$tableId');
    qrReads++;
    return PanelTableQr(
      tableId: tableId,
      code: 'T1-1',
      url: 'https://tavo.example/t/token-v1',
      version: 1,
    );
  }

  @override
  Future<PanelTableQr> rotateTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    calls.add('rotate:$tableId');
    qrRotates++;
    return PanelTableQr(
      tableId: tableId,
      code: 'T1-1',
      url: 'https://tavo.example/t/token-v2',
      version: 2,
    );
  }
}

TablesPanelCubit _cubit(TablesPanelRepo repo) =>
    TablesPanelCubit(repo, restaurantId: 'r1', autoRefresh: false);

void main() {
  group('floor payload', () {
    test('decodes kpi, party, tickets, asks and reservations', () {
      final snapshot = PanelFloorSnapshot.fromJson(_floorJson());
      final table = snapshot.tables.firstWhere((t) => t.id == 't1');

      expect(snapshot.kpi.salesToday, 1250.5);
      expect(snapshot.kpi.occupancyPct, 33);
      expect(snapshot.tables, hasLength(4));
      expect(table.floorStatus, 'occupied');
      expect(table.typeLabel, 'Indoor');
      expect(table.positioned, isTrue);
      expect(table.guestCount, 2);
      expect(table.openItemCount, 2);
      expect(table.billTotal, 120);
      expect(table.billRemaining, 120);
      expect(table.orders.single.orderNumber, 'ORD-1');
      expect(table.orders.single.items.single.name, 'Chicken Kabsa');
      expect(
        table.orders.single.items.single.specifications,
        ['Saffron rice (+4.00)'],
      );
      expect(table.pendingRequests.single.id, 'req1');
      expect(table.hasAttention, isTrue);
      expect(snapshot.reservations, hasLength(2));
      expect(
        snapshot.tables.firstWhere((t) => t.id == 't3').reservation?.customerName,
        'Sara',
      );
    });

    test('displayStatus outranks a stale raw status', () {
      final table = PanelPhysicalTable.fromJson(
        _tableJson(
          id: 't9',
          status: 'reserved',
          displayStatus: 'occupied',
          session: _sessionJson(),
        ),
      );
      expect(table.floorStatus, 'occupied');
    });

    test('falls back to local precedence when displayStatus is absent', () {
      final reserved = PanelPhysicalTable.fromJson({
        ..._tableJson(id: 't8', status: 'reserved'),
        'displayStatus': '',
      });
      expect(reserved.floorStatus, 'reserved');
    });
  });

  group('floor filters', () {
    test('search matches code, zone, guest name and phone', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      var state = cubit.state as TablesPanelLoaded;

      expect(state.visibleTables, hasLength(4));

      cubit.setFilter(FloorFilter.occupied);
      state = cubit.state as TablesPanelLoaded;
      expect(state.visibleTables.map((t) => t.code), ['T1-1']);

      cubit.setFilter(FloorFilter.reserved);
      cubit.setZone('Terrace');
      state = cubit.state as TablesPanelLoaded;
      expect(state.visibleTables.map((t) => t.code), ['T2-1']);

      cubit.setZone(null);
      cubit.setQuery('sara');
      state = cubit.state as TablesPanelLoaded;
      expect(state.visibleTables.map((t) => t.code), ['T2-1']);

      cubit.setQuery('0550000000');
      state = cubit.state as TablesPanelLoaded;
      expect(state.visibleTables.map((t) => t.code), ['T2-1']);

      cubit.clearFilters();
      state = cubit.state as TablesPanelLoaded;
      expect(state.visibleTables, hasLength(4));
      expect(state.filter, FloorFilter.all);
      expect(state.zone, isNull);
      expect(state.query, isEmpty);
    });

    test('zones and counts come from the same rows', () async {
      final cubit = _cubit(_FakeTablesRepo());
      addTearDown(cubit.close);
      await cubit.load();
      final state = cubit.state as TablesPanelLoaded;
      expect(state.zones, [ (zone: 'Indoor', count: 2), (zone: 'Terrace', count: 2) ]);
    });

    test('attention rail is oldest ask first', () async {
      final repo = _FakeTablesRepo()
        ..floor = _floorJson(tables: [
          _tableJson(
            id: 't1',
            code: 'T1-1',
            displayStatus: 'occupied',
            requests: [_requestJson(id: 'new', createdAt: '2026-10-26T12:10:00.000Z')],
          ),
          _tableJson(
            id: 't2',
            code: 'T1-2',
            displayStatus: 'occupied',
            requests: [_requestJson(id: 'old', createdAt: '2026-10-26T11:30:00.000Z')],
          ),
        ]);
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final state = cubit.state as TablesPanelLoaded;
      expect(state.attentionTables.map((t) => t.id), ['t2', 't1']);
    });
  });

  group('layout editing', () {
    test('snapToGrid rounds to exact 0.05 steps without float dust', () {
      expect(TablesPanelCubit.snapToGrid(0.07), 0.05);
      expect(TablesPanelCubit.snapToGrid(0.08), 0.10);
      expect(TablesPanelCubit.snapToGrid(0.51), 0.50);
      expect(TablesPanelCubit.snapToGrid(0.0), 0.0);
      expect(TablesPanelCubit.snapToGrid(0.999), 1.0);
      expect(TablesPanelCubit.snapToGrid(0.33).toString(), '0.35');
    });

    test('moveTable clamps and can snap', () async {
      final cubit = _cubit(_FakeTablesRepo());
      addTearDown(cubit.close);
      await cubit.load();

      cubit.moveTable('t1', 9.9, -2.0);
      var table = (cubit.state as TablesPanelLoaded).tableById('t1')!;
      expect(table.x, 1.0);
      expect(table.y, 0.0);

      cubit.moveTable('t1', 0.08, 0.07, snap: true);
      table = (cubit.state as TablesPanelLoaded).tableById('t1')!;
      expect(table.x, 0.10);
      expect(table.y, 0.05);
    });

    test('save failure keeps the local positions and reports the error',
        () async {
      final repo = _FakeTablesRepo()..saveError = Exception('offline');
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.moveTable('t1', 0.6, 0.6);

      final ok = await cubit.saveFloorPlan();
      final state = cubit.state as TablesPanelLoaded;

      expect(ok, isFalse);
      expect(state.saving, isFalse);
      expect(state.actionError, contains('offline'));
      expect(state.tableById('t1')!.x, 0.6);
      expect(repo.savedLayouts, isEmpty);
    });
  });

  group('mutations', () {
    test('handling an ask calls the endpoint and re-reads the floor', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      final ok = await cubit.handleRequest('t1', 'req1');
      final state = cubit.state as TablesPanelLoaded;

      expect(ok, isTrue);
      expect(repo.calls, contains('handle:t1:req1'));
      expect(repo.calls.last, 'getFloor');
      expect(state.tableById('t1')!.hasAttention, isFalse);
      expect(state.actionId, isNull);
    });

    test('settling frees the table on the refreshed floor', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      final ok = await cubit.settleTable('t1');
      final state = cubit.state as TablesPanelLoaded;

      expect(ok, isTrue);
      expect(repo.calls, contains('settle:t1:all'));
      expect(state.tableById('t1')!.floorStatus, 'available');
      expect(state.kpi.openBills, 2);
    });

    test('a failed mutation surfaces a message and clears the busy id',
        () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      repo.handleError = Exception('network is down');
      final ok = await cubit.handleRequest('t1', 'req1');
      final state = cubit.state as TablesPanelLoaded;

      expect(ok, isFalse);
      expect(state.actionId, isNull);
      expect(state.actionError, contains('network is down'));
      // The last good floor is still on screen.
      expect(state.tables, hasLength(4));
    });

    test('seat and no-show hit the reservation endpoints', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      expect(await cubit.seatReservation('res1'), isTrue);
      expect(await cubit.markReservationNoShow('res2'), isTrue);
      expect(repo.calls, containsAll([
        'reservation:res1:seat',
        'reservation:res2:no-show',
      ]));
    });

    test('status updates never send the legacy unavailable value', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final active = (cubit.state as TablesPanelLoaded).tableById('t2')!;

      await cubit.toggleStatus(active);
      expect(repo.calls, contains('status:t2:inactive'));
    });

    test('creating a table re-reads the floor', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      final ok = await cubit.createTable(
        tableTypeId: 'type1',
        code: 'T3-1',
        seats: 2,
        zone: 'Patio',
      );

      expect(ok, isTrue);
      expect(repo.calls, contains('create:T3-1'));
      expect(repo.calls.last, 'getFloor');
    });
  });

  group('qr', () {
    test('reprinting reuses the cached read; rotation replaces it', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      final first = await cubit.loadQr('t1');
      final again = await cubit.loadQr('t1');
      expect(first!.version, 1);
      expect(again!.version, 1);
      expect(repo.qrReads, 1);

      final rotated = await cubit.rotateQr('t1');
      expect(rotated!.version, 2);
      expect(repo.qrRotates, 1);
      expect((cubit.state as TablesPanelLoaded).qr['t1']!.version, 2);
      expect((cubit.state as TablesPanelLoaded).qrLoadingId, isNull);
    });

    test('a QR failure keeps the table usable and exposes retry state',
        () async {
      final repo = _FakeTablesRepo();
      // Sabotage only the QR read.
      final failing = _FailingQrRepo(repo);
      final failingCubit = _cubit(failing);
      addTearDown(failingCubit.close);
      await failingCubit.load();

      final qr = await failingCubit.loadQr('t1');
      final state = failingCubit.state as TablesPanelLoaded;
      expect(qr, isNull);
      expect(state.qrError, contains('QR unavailable'));
      expect(state.qrLoadingId, isNull);
      expect(state.tables, isNotEmpty);
    });
  });

  group('polling', () {
    test('a failed silent refresh keeps the last good snapshot and marks it',
        () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      final before = (cubit.state as TablesPanelLoaded).tables.length;

      repo.floorError = Exception('timeout');
      await cubit.refresh(silent: true);
      final state = cubit.state as TablesPanelLoaded;

      expect(state.stale, isTrue);
      expect(state.tables, hasLength(before));
      expect(state.kpi.salesToday, 1250.5);
    });

    test('a successful refresh clears stale', () async {
      final repo = _FakeTablesRepo();
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();

      repo.floorError = Exception('timeout');
      await cubit.refresh(silent: true);
      expect((cubit.state as TablesPanelLoaded).stale, isTrue);

      repo.floorError = null;
      await cubit.refresh(silent: true);
      expect((cubit.state as TablesPanelLoaded).stale, isFalse);
    });

    test('the first failure is an error state, not a stale empty floor',
        () async {
      final repo = _FakeTablesRepo()..floorError = Exception('boom');
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, isA<TablesPanelError>());
      expect((cubit.state as TablesPanelError).message, contains('boom'));
    });
  });
}

class _FailingQrRepo extends TablesPanelRepo {
  _FailingQrRepo(this._inner) : super(api: ApiService());
  final _FakeTablesRepo _inner;

  @override
  Future<PanelFloorSnapshot> getFloor(String restaurantId) =>
      _inner.getFloor(restaurantId);

  @override
  Future<PanelTableQr> getTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    throw Exception('QR unavailable');
  }

  @override
  Future<PanelTableQr> rotateTableQr({
    required String restaurantId,
    required String tableId,
  }) async {
    throw Exception('QR unavailable');
  }
}
