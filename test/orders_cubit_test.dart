// test/orders_cubit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_state.dart';

PanelOrder _order(String id, String status) => PanelOrder.fromJson({
      '_id': id,
      'orderNumber': 'ORD-$id',
      'orderStatus': status,
      'userId': {'name': 'Guest $id', 'phone': '+966500000000'},
      'menuItems': [
        {'name': 'Burger', 'quantity': 1, 'unitPrice': 30, 'lineTotal': 30}
      ],
      'totalPrice': 34.5,
      'createdAt': '2026-09-01T11:52:00.000Z',
    });

class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());
  List<PanelOrder> orders = [];
  int totalPages = 1;
  int getCalls = 0;
  String? failActionFor;
  String? lastStatusFilter;
  int lastPage = 1;
  String? lastActionRestaurantId;

  @override
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    getCalls++;
    lastPage = page;
    lastStatusFilter = status;
    return PagedResult(
      items: page == 1 ? orders : [],
      page: page,
      limit: limit,
      total: orders.length,
      pages: totalPages,
    );
  }

  @override
  Future<PanelOrder> updateOrderStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    lastActionRestaurantId = restaurantId;
    if (failActionFor == id) {
      throw 'Cannot change status from cancelled to $status';
    }
    final updated = _order(id, status);
    orders = [for (final o in orders) o.id == id ? updated : o];
    return updated;
  }
}

void main() {
  late FakePanelRepo repo;
  late OrdersCubit cubit;

  setUp(() {
    repo = FakePanelRepo()
      ..orders = [_order('a', 'pending'), _order('b', 'ready')];
    cubit = OrdersCubit(repo, restaurantId: 'r1');
  });
  tearDown(() => cubit.close());

  test('load emits Loaded with page 1 of all orders', () async {
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<OrdersLoading>(),
        predicate<OrdersLoaded>(
            (s) => s.orders.length == 2 && s.filter == null && s.page == 1),
      ]),
    );
    await cubit.load();
    await expectation;
    expect(repo.lastPage, 1);
    expect(repo.lastStatusFilter, isNull);
  });

  test('setFilter resets to page 1 and passes the status', () async {
    await cubit.load();
    final expectation = expectLater(
      cubit.stream,
      emits(predicate<OrdersLoaded>(
          (s) => s.filter == 'pending' && s.page == 1)),
    );
    await cubit.setFilter('pending');
    await expectation;
    expect(repo.lastStatusFilter, 'pending');
    expect(repo.lastPage, 1);
  });

  test('loadMore appends the next page when hasNext', () async {
    repo.totalPages = 2;
    await cubit.load();

    final expectation = expectLater(
      cubit.stream,
      emits(predicate<OrdersLoaded>((s) => s.page == 2)),
    );
    await cubit.loadMore();
    await expectation;
  });

  test('updateStatus replaces the row on success', () async {
    await cubit.load();

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        predicate<OrdersLoaded>((s) => s.actingId == 'a'),
        predicate<OrdersLoaded>(
            (s) => s.actingId == null &&
                s.orders.firstWhere((o) => o.id == 'a').orderStatus ==
                    'confirmed'),
      ]),
    );
    await cubit.updateStatus('a', 'confirmed');
    await expectation;
    expect(repo.lastActionRestaurantId, 'r1',
        reason: 'cubit must forward ITS venue — cross-venue wrong-target risk');
  });

  test('failed updateStatus keeps rows and surfaces actionError', () async {
    repo.failActionFor = 'a';
    await cubit.load();

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        predicate<OrdersLoaded>((s) => s.actingId == 'a'),
        predicate<OrdersLoaded>(
            (s) =>
                s.actingId == null &&
                s.orders.length == 2 &&
                (s.actionError ?? '').contains('Cannot change status')),
      ]),
    );
    await cubit.updateStatus('a', 'confirmed');
    await expectation;
  });

  test('updateStatus before load is a no-op', () async {
    final states = <OrdersState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.updateStatus('a', 'confirmed');
    await sub.cancel();
    expect(states, isEmpty);
  });
}
