// test/panel_customers_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_customers/data/model/customer_models.dart';
import 'package:tavo/feature/panel_customers/data/repo/customers_panel_repo.dart';
import 'package:tavo/feature/panel_customers/ui/logic/customer_detail_cubit.dart';
import 'package:tavo/feature/panel_customers/ui/screens/customer_detail_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/customers_screen.dart';

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

PanelCustomer _customer(String key, String name,
        {int orders = 2, int reservations = 1}) =>
    PanelCustomer(
        key: key,
        name: name,
        phone: '+966501112233',
        orderCount: orders,
        reservationCount: reservations,
        totalSpent: 200);

PanelCustomerDetail _detail(PanelCustomer c) => PanelCustomerDetail(
      profile: c,
      orders: [
        {
          'orderNumber': 'ORD-1',
          'totalPrice': 120,
          'orderStatus': 'served',
          'createdAt': '2026-09-29T18:00:00.000Z'
        }
      ],
      reservations: [
        {
          'startAt': '2026-10-01T19:00:00.000Z',
          'guestsCount': 2,
          'status': 'completed'
        }
      ],
    );

class _FakeCustomersRepo extends CustomersPanelRepo {
  _FakeCustomersRepo() : super(api: ApiService());
  List<PanelCustomer> customers = [];
  Object? failure;
  final List<String> calls = [];

  @override
  Future<({List<PanelCustomer> customers, int page, int pages, int total})>
      getCustomers(String restaurantId, {int page = 1, String? search}) async {
    calls.add('getCustomers:$page:${search ?? '*'}');
    _maybeThrow();
    final visible = search == null || search.isEmpty
        ? customers
        : customers
            .where((c) =>
                c.name.toLowerCase().contains(search.toLowerCase()) ||
                c.phone.contains(search))
            .toList();
    return (customers: visible, page: page, pages: 1, total: visible.length);
  }

  @override
  Future<PanelCustomerDetail> getCustomerDetail(
      String restaurantId, String key) async {
    calls.add('detail:$key');
    _maybeThrow();
    return _detail(customers.firstWhere((c) => c.key == key));
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

Future<void> _pumpCustomers(WidgetTester tester, _FakeCustomersRepo repo) async {
  GetIt.instance.registerLazySingleton<CustomersPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(
      appShell(CustomersScreen(restaurantId: 'r1', venue: _venue)));
  // Mirrors panel_menu_test / panel_reviews_test: EasyLocalization builds
  // the child subtree asynchronously, so wait for the skeleton first.
  await pumpUntil(
      tester, () => find.byType(ListSkeleton).evaluate().isNotEmpty);
}

void main() {
  setUpAll(initTestEnv);

  testWidgets('loading shows the skeleton before content', (tester) async {
    await _pumpCustomers(tester, _FakeCustomersRepo());
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ListSkeleton), findsNothing);
  });

  testWidgets('empty customers show the composed empty state',
      (tester) async {
    await _pumpCustomers(tester, _FakeCustomersRepo());
    await tester.pumpAndSettle();
    expect(find.text('No customers yet'), findsOneWidget);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeCustomersRepo()..failure = Exception('boom');
    await _pumpCustomers(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    await tester.tap(find.byIcon(Iconsax.refresh));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('getCustomers:1:*'));
  });

  testWidgets('search refetches with the query', (tester) async {
    final repo = _FakeCustomersRepo()
      ..customers = [
        _customer('+966501112233', 'Noura Said'),
        _customer('abc123', 'Member One', orders: 1, reservations: 1),
      ];
    await _pumpCustomers(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Noura Said'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('customer_search')), 'noura');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('getCustomers:1:noura'));
    expect(find.text('Noura Said'), findsOneWidget);
    expect(find.text('Member One'), findsNothing);
  });

  testWidgets('row tap pushes the detail screen with histories',
      (tester) async {
    final repo = _FakeCustomersRepo()
      ..customers = [_customer('+966501112233', 'Noura Said')];
    await _pumpCustomers(tester, repo);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Noura Said'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('detail:+966501112233'));
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    expect(find.text('ORD-1'), findsOneWidget); // order history
    expect(find.text('Order history'), findsOneWidget);
    expect(find.text('Reservation history'), findsOneWidget);
  });

  testWidgets('detail shows fallbacks when histories are empty',
      (tester) async {
    final c = _customer('+966501112233', 'Noura Said');
    await tester.pumpWidget(appShell(CustomerDetailScreen(
        detail: PanelCustomerDetail(profile: c, orders: const [], reservations: const []))));
    await tester.pumpAndSettle();

    expect(find.text('No orders'), findsOneWidget);
    expect(find.text('No reservations'), findsOneWidget);
  });

  test('detail cubit loads profile + histories', () async {
    final repo = _FakeCustomersRepo()
      ..customers = [_customer('+966501112233', 'Noura Said')];
    final cubit = CustomerDetailCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);

    await cubit.load('+966501112233');

    final loaded = cubit.state as CustomerDetailLoaded;
    expect(loaded.detail.profile.name, 'Noura Said');
    expect(loaded.detail.orders, hasLength(1));
    expect(loaded.detail.reservations, hasLength(1));
  });
}
