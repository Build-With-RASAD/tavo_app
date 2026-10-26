// test/orders_screen_widget_test.dart
//
// Widget coverage for `OrdersScreen` (Task 10). Derived from the brief's
// test with these amendments (controller rulings / repo reality):
//   * chip taps go through `ValueKey('orders_filter_<status>')` — a bare
//     `find.text('Ready')` is ambiguous (chip vs the ready order's badge);
//   * `FakePanelRepo.updateOrderStatus` threads `restaurantId` (Task 8's
//     amended repo signature);
//   * the failure SnackBar holds the FULL message, so the finder uses
//     `textContaining`;
//   * row assertions are scoped to the card (`order_card_<id>`) because the
//     filter chips share label text with the badges;
//   * the details-sheet payment assertion is scoped to the sheet — the card
//     underneath stays in the tree while a modal sheet is open.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/orders_screen.dart';

import 'helpers/app_shell.dart';

PanelOrder _order(String id, String status, {String name = 'سعد السبيعي'}) =>
    PanelOrder.fromJson({
      '_id': id,
      'orderNumber': 'ORD-2026-01$id',
      'orderStatus': status,
      'userId': {'name': name, 'phone': '+966515033695'},
      'menuItems': [
        {
          'name': 'Smoky BBQ Burger',
          'quantity': 3,
          'unitPrice': 32,
          'lineTotal': 96,
        },
      ],
      'subtotal': 96,
      'tax': 14.4,
      'totalPrice': 110.4,
      'paymentStatus': 'paid',
      'createdAt': '2026-09-01T11:52:00.000Z',
    });

class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());

  List<PanelOrder> orders = [];
  List<PanelOrder> page2Orders = [];

  /// Total pages the fake advertises — 1 (default) keeps every existing
  /// test single-page; 2 lets a test exercise the scroll-end `loadMore`.
  int totalPages = 1;

  /// Every `page` value the screen asked the repo for.
  final List<int> pagesServed = [];

  /// When set, page 2 suspends on this future so a test can observe the
  /// footer loading indicator while the next page is in flight.
  Completer<void>? page2Gate;

  Object? loadError;
  String? failActionFor;
  String? lastFilter;
  String? lastActionStatus;

  @override
  Future<PagedResult<PanelOrder>> getOrders(
    String restaurantId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    lastFilter = status;
    pagesServed.add(page);
    if (loadError != null) throw loadError!;
    if (page > 1 && page2Gate != null) await page2Gate!.future;
    return PagedResult(
      items: page == 1 ? orders : page2Orders,
      page: page,
      limit: limit,
      total: orders.length + page2Orders.length,
      pages: totalPages,
    );
  }

  @override
  Future<PanelOrder> updateOrderStatus({
    required String restaurantId,
    required String id,
    required String status,
  }) async {
    lastActionStatus = status;
    if (failActionFor == id) {
      throw 'Cannot change status from cancelled to $status';
    }
    final updated = PanelOrder.fromJson({
      '_id': id,
      'orderNumber': 'ORD-2026-01$id',
      'orderStatus': status,
      'userId': {'name': 'سعد السبيعي', 'phone': '+966515033695'},
      'totalPrice': 110.4,
      'paymentStatus': 'paid',
      'createdAt': '2026-09-01T11:52:00.000Z',
    });
    orders = [for (final o in orders) o.id == id ? updated : o];
    return updated;
  }
}

/// The badge inside the `order_card_<id>` row — scoped so a chip with the
/// same label can't satisfy the assertion.
Finder _rowBadge(String id, String label) => find.descendant(
  of: find.byKey(ValueKey('order_card_$id')),
  matching: find.text(label),
);

void main() {
  setUpAll(initTestEnv);
  late FakePanelRepo repo;
  final getIt = GetIt.instance;

  setUp(() {
    repo = FakePanelRepo()
      ..orders = [_order('1', 'pending'), _order('2', 'ready')];
    getIt
      ..registerFactory<RestaurantPanelRepo>(() => repo)
      ..registerFactoryParam<OrdersCubit, String, void>(
        (id, _) => OrdersCubit(repo, restaurantId: id),
      );
  });
  tearDown(getIt.reset);

  testWidgets('lists orders with status filter chips', (tester) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ORD-2026-011'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
  });

  testWidgets('the screen filters by the status it was given', (tester) async {
    await tester.pumpWidget(
      appShell(const OrdersScreen(restaurantId: 'r1', statusFilter: 'pending')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The repo was asked for the given status…
    expect(repo.lastFilter, 'pending');
    // …the chip row shows it…
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('orders_filter_pending')),
    );
    expect(chip.selected, isTrue);
    // …and the header says so too: never a silent filter.
    expect(
      find.byKey(const ValueKey('orders_active_filter')),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('the header names the active filter', (tester) async {
    await tester.pumpWidget(
      appShell(const OrdersScreen(restaurantId: 'r1', statusFilter: 'ready')),
    );
    await tester.pumpAndSettle();

    expect(repo.lastFilter, 'ready');
    final pill = find.byKey(const ValueKey('orders_active_filter'));
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: find.text('Ready')),
      findsOneWidget,
    );
  });

  testWidgets('no status filter means no filter pill', (tester) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(repo.lastFilter, isNull);
    expect(find.byKey(const ValueKey('orders_active_filter')), findsNothing);
  });

  testWidgets('a chip tap reports the new filter to the owner', (tester) async {
    String? reported;
    await tester.pumpWidget(
      appShell(
        OrdersScreen(
          restaurantId: 'r1',
          onStatusFilterChanged: (status) => reported = status,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('orders_filter_served'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(repo.lastFilter, 'served');
    expect(reported, 'served');
  });

testWidgets('served filter chip exists and filters through the repo', (
    tester,
  ) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('orders_filter_served'));
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(repo.lastFilter, 'served');
    expect(find.text('Served'), findsWidgets);
  });

  testWidgets('no delivered string renders anywhere in the orders flow', (
    tester,
  ) async {
    repo.orders = [_order('1', 'pending'), _order('2', 'served')];
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('orders_filter_delivered')), findsNothing);
    expect(find.text('Delivered'), findsNothing);
    expect(find.text('delivered'), findsNothing);
  });

  testWidgets('tapping a status chip filters through the repo', (tester) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    // Ruling: tap chips by key — the Ready chip and the ready row's badge
    // share the same label.
    final chip = find.byKey(const ValueKey('orders_filter_ready'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(repo.lastFilter, 'ready');
  });

  testWidgets('status action updates the row', (tester) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    // pending row shows Confirm + Cancel targets
    await tester.tap(find.text('Confirm').first);
    await tester.pump();
    await pumpUntil(
      tester,
      () => _rowBadge('1', 'Confirmed').evaluate().isNotEmpty,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('failed action keeps the list and shows the message', (
    tester,
  ) async {
    repo.failActionFor = '1';
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm').first);
    await tester.pump();
    // The SnackBar carries the full backend message ('Cannot change status
    // from cancelled to confirmed'), so match on the prefix.
    await pumpUntil(
      tester,
      () => find.textContaining('Cannot change status').evaluate().isNotEmpty,
    );

    expect(find.text('ORD-2026-011'), findsOneWidget); // row still there

    // Let the SnackBar auto-dismiss so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('tap on an order opens the details sheet', (tester) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ORD-2026-011'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailsSheet), findsOneWidget);
    expect(find.text('Order details'), findsOneWidget);
    // The order card also lists its lines now, so scope the item assertion to
    // the sheet instead of matching the row behind it.
    expect(
      find.descendant(
        of: find.byType(OrderDetailsSheet),
        matching: find.text('Smoky BBQ Burger'),
      ),
      findsOneWidget,
    );
    // The card below the modal sheet shows a payment pill too — scope to
    // the sheet so the pair doesn't read as a duplicate.
    expect(
      find.descendant(
        of: find.byType(OrderDetailsSheet),
        matching: find.text('Paid'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('load error shows retry', (tester) async {
    repo.loadError = 'No internet connection';
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('destructive cancel asks through an action sheet', (
    tester,
  ) async {
    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();

    // Nothing is sent until the sheet is confirmed.
    expect(find.byType(CancelOrderSheet), findsOneWidget);
    expect(repo.lastActionStatus, isNull);

    await tester.tap(find.byKey(const ValueKey('cancel_order_confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(CancelOrderSheet), findsNothing);
    expect(repo.lastActionStatus, 'cancelled');
    await pumpUntil(
      tester,
      () => _rowBadge('1', 'Cancelled').evaluate().isNotEmpty,
    );
  });

  testWidgets('scrolling near the bottom loads page 2 behind a footer spinner', (
    tester,
  ) async {
    repo
      ..totalPages = 2
      ..orders = [for (var i = 1; i <= 20; i++) _order('$i', 'pending')]
      ..page2Orders = [_order('90', 'ready')]
      ..page2Gate = Completer<void>();

    await tester.pumpWidget(appShell(const OrdersScreen(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('order_card_90')), findsNothing);

    // The list is taller than one drag — drag until the viewport reaches
    // the end (the trigger fires within ~200px of the bottom). The vertical
    // board is addressed by key: the status chip row is a horizontal
    // ListView too, so `byType(ListView).first` is no longer the board.
    for (var i = 0; i < 5 && !repo.pagesServed.contains(2); i++) {
      await tester.drag(
        find.byKey(const ValueKey('orders_list')),
        const Offset(0, -2000),
      );
      await tester.pump();
    }

    expect(
      repo.pagesServed,
      contains(2),
      reason: 'loadMore must be reachable from the list (I-1)',
    );
    expect(
      find.byKey(const ValueKey('orders_load_more_footer')),
      findsOneWidget,
      reason: 'footer spinner shows while page 2 is in flight',
    );

    repo.page2Gate!.complete();
    await tester.pumpAndSettle();

    // Second drag: reveal the appended tail and re-arm the trigger (a
    // no-op now that hasNext is false).
    await tester.drag(
      find.byKey(const ValueKey('orders_list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('order_card_90')),
      findsOneWidget,
      reason: 'page-2 row appears after the append',
    );
    expect(find.byKey(const ValueKey('orders_load_more_footer')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
