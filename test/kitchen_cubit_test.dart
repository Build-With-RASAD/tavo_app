// test/kitchen_cubit_test.dart
//
// Kitchen display: station grouping, the two-step start for pending orders and
// the table metadata the board needs.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/kitchen/ui/logic/kitchen_cubit.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';

PanelOrder _order(
  String id, {
  required String status,
  String tableCode = 'A12',
  String source = 'qr_table',
  String createdAt = '2026-10-24T20:00:00.000Z',
}) => PanelOrder(
  id: id,
  orderNumber: id,
  customerName: 'Guest',
  customerPhone: '',
  items: const [
    OrderLine(name: 'Kabsa', quantity: 2, unitPrice: 50, lineTotal: 100),
  ],
  subtotal: 100,
  tax: 15,
  totalPrice: 115,
  paymentStatus: 'unpaid',
  orderStatus: status,
  createdAt: createdAt,
  tableCode: tableCode,
  source: source,
  sessionCode: '$tableCode-1',
);

class _FakePanelRepo extends RestaurantPanelRepo {
  _FakePanelRepo() : super(ApiService());

  List<PanelOrder> orders = [];
  final List<String> statusCalls = [];
  Object? loadError;
  Object? updateError;
  int loadCount = 0;

  @override
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    loadCount += 1;
    final error = loadError;
    if (error != null) throw error;
    return PagedResult(
      items: List<PanelOrder>.from(orders),
      page: 1,
      limit: limit,
      total: orders.length,
      pages: 1,
    );
  }

  @override
  Future<PanelOrder> updateOrderStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    statusCalls.add('$id:$status');
    final error = updateError;
    if (error != null) throw error;

    orders = [
      for (final order in orders)
        if (order.id == id) _order(id, status: status) else order,
    ];
    return orders.firstWhere((order) => order.id == id);
  }
}

void main() {
  group('PanelOrder table metadata', () {
    test('reads the populated table and session blocks', () {
      final order = PanelOrder.fromJson({
        '_id': 'o1',
        'orderNumber': 42,
        'orderStatus': 'preparing',
        'source': 'qr_table',
        'tableId': {'code': 'B7', 'zone': 'Garden'},
        'sessionId': {'code': 'B7-2'},
        'createdAt': '2026-10-24T20:00:00.000Z',
      });

      expect(order.tableCode, 'B7');
      expect(order.zone, 'Garden');
      expect(order.sessionCode, 'B7-2');
      expect(order.isTableOrder, isTrue);
      expect(order.minutesWaiting(DateTime.utc(2026, 10, 24, 20, 12)), 12);
    });

    test('a delivery order has no table and never reports negative waits', () {
      final order = PanelOrder.fromJson({
        '_id': 'o2',
        'orderStatus': 'pending',
        'createdAt': '2026-10-24T20:00:00.000Z',
      });

      expect(order.tableCode, isEmpty);
      expect(order.isTableOrder, isFalse);
      expect(order.minutesWaiting(DateTime.utc(2026, 10, 24, 19, 0)), 0);
    });
  });

  group('KitchenCubit', () {
    test('splits active orders into stations and drops served ones', () async {
      final repo = _FakePanelRepo()
        ..orders = [
          _order('1', status: 'pending'),
          _order('2', status: 'confirmed'),
          _order('3', status: 'preparing'),
          _order('4', status: 'ready'),
          _order('5', status: 'served'),
          _order('6', status: 'cancelled'),
        ];
      final cubit = KitchenCubit(repo, restaurantId: 'r1');

      await cubit.load();

      final board = cubit.state as KitchenBoard;
      expect(board.incoming.map((o) => o.id), ['1', '2']);
      expect(board.preparing.map((o) => o.id), ['3']);
      expect(board.ready.map((o) => o.id), ['4']);
      expect(board.orders.length, 4);
      await cubit.close();
    });

    test('starting a pending order confirms it and starts cooking', () async {
      final repo = _FakePanelRepo()..orders = [_order('1', status: 'pending')];
      final cubit = KitchenCubit(repo, restaurantId: 'r1');
      await cubit.load();

      await cubit.advance(
        (cubit.state as KitchenBoard).incoming.single,
      );

      expect(repo.statusCalls, ['1:confirmed', '1:preparing']);
      final board = cubit.state as KitchenBoard;
      expect(board.preparing.map((o) => o.id), ['1']);
      expect(board.incoming, isEmpty);
      expect(board.updatingId, isNull);
      await cubit.close();
    });

    test('ready is one tap from the pass', () async {
      final repo = _FakePanelRepo()..orders = [_order('4', status: 'ready')];
      final cubit = KitchenCubit(repo, restaurantId: 'r1');
      await cubit.load();

      await cubit.advance((cubit.state as KitchenBoard).ready.single);

      expect(repo.statusCalls, ['4:served']);
      expect((cubit.state as KitchenBoard).orders, isEmpty);
      await cubit.close();
    });

    test('a failed status change keeps the board and reports the error', () async {
      final repo = _FakePanelRepo()
        ..orders = [_order('3', status: 'preparing')]
        ..updateError = 'Cannot change status from preparing to ready';
      final cubit = KitchenCubit(repo, restaurantId: 'r1');
      await cubit.load();

      await cubit.advance((cubit.state as KitchenBoard).preparing.single);

      final board = cubit.state as KitchenBoard;
      expect(board.preparing, hasLength(1));
      expect(board.updatingId, isNull);
      expect(board.actionError, contains('Cannot change status'));
      await cubit.close();
    });

    test('a first-load failure is retryable', () async {
      final repo = _FakePanelRepo()..loadError = 'Network down';
      final cubit = KitchenCubit(repo, restaurantId: 'r1');

      await cubit.load();
      expect((cubit.state as KitchenFailure).message, 'Network down');

      repo.loadError = null;
      repo.orders = [_order('1', status: 'pending')];
      await cubit.load();
      expect(cubit.state, isA<KitchenBoard>());
      await cubit.close();
    });
  });
}
