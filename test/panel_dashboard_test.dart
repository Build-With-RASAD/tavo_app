// test/panel_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/dashboard_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_extras_cubit.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/floor_strip.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/orders_summary.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/quick_actions.dart';
import 'package:tavo/feature/panel_dashboard/ui/widgets/waitlist_preview.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';

import 'helpers/app_shell.dart';

const _tAvailable = PanelPhysicalTable(
    id: 't1', tableTypeId: 'h1', code: 'A-1', seats: 4, status: 'available');
const _tReserved = PanelPhysicalTable(
    id: 't2', tableTypeId: 'h1', code: 'A-2', seats: 2, status: 'reserved');
const _tOccupied = PanelPhysicalTable(
    id: 't3', tableTypeId: 'h1', code: 'A-3', seats: 6, status: 'available');
const _tInactive = PanelPhysicalTable(
    id: 't4', tableTypeId: 'h1', code: 'A-4', seats: 4, status: 'inactive');

PanelWaitlistEntry _waitEntry(String id) => PanelWaitlistEntry(
      id: id,
      ticketCode: 'T$id',
      guestsCount: 2,
      customerName: 'Guest $id',
      customerPhone: '+966500000001',
      status: 'waiting',
      createdAt: '2026-09-30T10:00:00.000Z',
    );

DashboardOpenOrder _order(String id, String status, String tableId) =>
    DashboardOpenOrder(id: id, orderStatus: status, tableId: tableId);

class _FakeDashboardRepo extends DashboardPanelRepo {
  _FakeDashboardRepo() : super(api: ApiService());

  List<PanelPhysicalTable> tables = [];
  List<PanelWaitlistEntry> waitlist = [];
  int waitlistTotal = 0;
  List<DashboardOpenOrder> orders = [];
  Object? failure;

  // Timer-based latency (not a microtask) so the skeleton frame stays
  // observable after pumpWidget+pump — mirrors the waitlist fake.
  static const _latency = Duration(milliseconds: 10);

  @override
  Future<List<PanelPhysicalTable>> getFloorTables(String restaurantId) async {
    await Future<void>.delayed(_latency);
    _maybeThrow();
    return tables;
  }

  @override
  Future<({List<PanelWaitlistEntry> entries, int total})> getWaitlistPreview(
      String restaurantId) async {
    await Future<void>.delayed(_latency);
    _maybeThrow();
    return (entries: waitlist, total: waitlistTotal);
  }

  @override
  Future<List<DashboardOpenOrder>> getOpenOrders(
      String restaurantId) async {
    await Future<void>.delayed(_latency);
    _maybeThrow();
    return orders;
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

/// Minimal extras composition: skeleton → error+retry → the four widgets.
/// Shell tab-switch wiring stays a controller diff (reported, not built).
class _ExtrasHarness extends StatelessWidget {
  const _ExtrasHarness(
      {required this.repo,
      this.onOpenOrders,
      this.onOpenWaitlist,
      this.onNewOrder});

  final _FakeDashboardRepo repo;
  final void Function(String status)? onOpenOrders;
  final VoidCallback? onOpenWaitlist;
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardExtrasCubit(repo, restaurantId: 'r1')..load(),
      child: BlocBuilder<DashboardExtrasCubit, DashboardExtrasState>(
        builder: (context, state) {
          if (state is DashboardExtrasError) {
            return Scaffold(
              body: ErrorStateView(
                message: state.message,
                onRetry: () =>
                    context.read<DashboardExtrasCubit>().load(),
              ),
            );
          }
          if (state is DashboardExtrasLoaded) {
            return Scaffold(
              body: ListView(
                children: [
                  QuickActions(onNewOrder: onNewOrder),
                  FloorStrip(
                      tables: state.tables,
                      occupiedIds: state.occupiedIds),
                  WaitlistPreview(
                    entries: state.waitlist,
                    total: state.waitlistTotal,
                    onOpenWaitlist: onOpenWaitlist,
                  ),
                  OrdersSummary(
                    ordersByStatus: state.ordersByStatus,
                    onOpenOrders: onOpenOrders,
                  ),
                ],
              ),
            );
          }
          return const Scaffold(body: ListSkeleton());
        },
      ),
    );
  }
}

Future<void> _pumpExtras(WidgetTester tester, _FakeDashboardRepo repo,
    {void Function(String status)? onOpenOrders,
    VoidCallback? onOpenWaitlist,
    VoidCallback? onNewOrder}) async {
  GetIt.instance.registerLazySingleton<DashboardPanelRepo>(() => repo);
  addTearDown(GetIt.instance.reset);
  await tester.pumpWidget(appShell(_ExtrasHarness(
    repo: repo,
    onOpenOrders: onOpenOrders,
    onOpenWaitlist: onOpenWaitlist,
    onNewOrder: onNewOrder,
  )));
}

_FakeDashboardRepo _seeded() => _FakeDashboardRepo()
  ..tables = [_tAvailable, _tReserved, _tOccupied, _tInactive]
  ..waitlist = [_waitEntry('1'), _waitEntry('2')]
  ..waitlistTotal = 7
  ..orders = [
    _order('o1', 'preparing', 't3'), // A-3 occupied via open order
    _order('o2', 'ready', 't2'), // reserved + open order stays red? no: orange
    _order('o3', 'served', 't1'), // terminal: must NOT occupy A-1
    _order('o4', 'cancelled', 't1'), // terminal: must NOT occupy A-1
  ];

void main() {
  setUpAll(initTestEnv);

  test('registerDashboardModule registers the repo without a hub tile', () {
    addTearDown(GetIt.instance.reset);
    registerDashboardModule();
    expect(GetIt.instance.isRegistered<DashboardPanelRepo>(), isTrue);
  });

  test('load derives occupiedIds from open orders only', () async {
    final repo = _seeded();
    final cubit = DashboardExtrasCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.load();

    final loaded = cubit.state as DashboardExtrasLoaded;
    // t3 occupied via preparing order; t2 occupied via ready order;
    // t1 free (served/cancelled are terminal); t4 inactive, no order.
    expect(loaded.occupiedIds, {'t3', 't2'});
    expect(loaded.ordersByStatus,
        {'preparing': 1, 'ready': 1, 'served': 1, 'cancelled': 1});
    expect(loaded.waitlistTotal, 7);
    expect(loaded.tables, hasLength(4));
  });

  testWidgets('skeleton first frame, then the extras content', (tester) async {
    await _pumpExtras(tester, _seeded());
    await tester.pump();
    expect(find.byType(ListSkeleton), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(QuickActions), findsOneWidget);
    expect(find.byType(FloorStrip), findsOneWidget);
    expect(find.byType(WaitlistPreview), findsOneWidget);
    expect(find.byType(OrdersSummary), findsOneWidget);
  });

  testWidgets('floor colors: reserved red, free green, occupied orange, '
      'inactive grey', (tester) async {
    await _pumpExtras(tester, _seeded());
    await tester.pumpAndSettle();

    Color dotOf(String tableId) {
      final card = tester.widget<Container>(
          find.byKey(ValueKey('floor_dot_$tableId')));
      return card.color ??
          (card.decoration! as BoxDecoration).color ??
          const Color(0x00000000);
    }

    // Static mapping pins the priority: inactive > occupied > reserved.
    expect(FloorStrip.colorFor(_tReserved, {}), Colors.red);
    expect(FloorStrip.colorFor(_tReserved, {'t2'}), Colors.orange);
    expect(FloorStrip.colorFor(_tAvailable, {}), Colors.green);
    expect(FloorStrip.colorFor(_tInactive, {'t4'}), Colors.grey);

    // Occupied-via-order (t3) renders orange even though physically available.
    expect(dotOf('t3'), Colors.orange);
    // Terminal orders never occupy: A-1 stays green.
    expect(dotOf('t1'), Colors.green);
    // Physical reserved renders red …
    expect(dotOf('t2'), Colors.orange); // … but its open order turns it orange.
    // t4 starts off-viewport in the horizontal strip: drag the strip left
    // (lazy ListView) before asserting its dot.
    await tester.drag(
      find.byKey(const ValueKey('floor_table_t1')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(dotOf('t4'), Colors.grey);
  });

  testWidgets('quick actions render both entries', (tester) async {
    await _pumpExtras(tester, _seeded());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dash_quick_waitlist')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_quick_order')), findsOneWidget);
  });

  testWidgets('waitlist preview shows the total count', (tester) async {
    await _pumpExtras(tester, _seeded());
    await tester.pumpAndSettle();

    expect(find.text('Guest 1'), findsOneWidget);
    expect(find.textContaining('7'), findsWidgets);
  });

  testWidgets('orders chips fire onOpenOrders with the status', (tester) async {
    String? opened;
    await _pumpExtras(tester, _seeded(),
        onOpenOrders: (s) => opened = s);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('orders_chip_ready')));
    expect(opened, 'ready');
  });

  testWidgets('waitlist view-all fires onOpenWaitlist', (tester) async {
    var opened = false;
    await _pumpExtras(tester, _seeded(), onOpenWaitlist: () => opened = true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dash_open_waitlist')));
    expect(opened, isTrue);
  });

  testWidgets('error shows an inline error with a working retry',
      (tester) async {
    final repo = _FakeDashboardRepo()..failure = Exception('boom');
    await _pumpExtras(tester, repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);

    repo.tables = [_tAvailable];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('A-1'), findsOneWidget);
  });
}
