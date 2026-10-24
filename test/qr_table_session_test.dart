// test/qr_table_session_test.dart
//
// QR table experience: wire-model tolerance, the guest session state machine
// and the `/t/<token>` deep link. No network, no platform channels.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/navigation/deep_link_service.dart';
import 'package:tavo/core/navigation/deep_link_target.dart';
import 'package:tavo/feature/qr_table/data/model/table_session_models.dart';
import 'package:tavo/feature/qr_table/data/repo/qr_table_repo.dart';
import 'package:tavo/feature/qr_table/ui/logic/table_session_cubit.dart';

TableContext _context() => const TableContext(
  restaurantId: 'r1',
  restaurantName: 'Tavo',
  restaurantNameAr: 'تافو',
  slug: 'tavo',
  logoUrl: '',
  tableId: 't1',
  tableCode: 'A12',
  zone: 'Terrace',
  seats: 4,
  hasActiveSession: true,
  guestCount: 2,
);

TableSnapshot _snapshot({
  bool hasRated = false,
  List<TableOrder> orders = const [],
}) => TableSnapshot(
  sessionId: 's1',
  code: 'A12-1',
  guestCount: 2,
  guests: const ['Guest 1', 'Guest 2'],
  orders: orders,
  bill: const TableBill(
    subtotal: 100,
    tax: 15,
    total: 115,
    paid: 0,
    currency: 'SAR',
  ),
  myLabel: 'Guest 1',
  canOrder: true,
  hasRated: hasRated,
);

TableOrder _order({String status = 'preparing'}) => TableOrder(
  id: 'o1',
  orderNumber: '1042',
  status: status,
  items: const [
    TableOrderLine(
      name: 'Kabsa',
      quantity: 2,
      unitPrice: 50,
      lineTotal: 100,
      specifications: ['extra rice'],
      addedByGuestId: 'g1',
    ),
  ],
  subtotal: 100,
  tax: 15,
  total: 115,
  notes: '',
  addedByMe: true,
  placedAt: DateTime(2026, 10, 24, 20, 30),
);

class _MemoryStore implements TableGuestStore {
  final Map<String, String> saved = {};

  @override
  Future<String?> read(String qrToken) async => saved[qrToken];

  @override
  Future<void> write(String qrToken, String guestToken) async {
    saved[qrToken] = guestToken;
  }

  @override
  Future<void> clear() async => saved.clear();
}

class _FakeRepo implements QrTableRepo {
  final List<String> calls = [];
  int joinCount = 0;
  Object? resolveError;
  String? deadToken;
  List<TableCartLine> lastLines = const [];
  RatingDraft? lastDraft;
  TableSnapshot snapshot = _snapshot();

  @override
  Future<TableContext> resolve(String qrToken) async {
    calls.add('resolve');
    final error = resolveError;
    if (error != null) throw error;
    return _context();
  }

  @override
  Future<JoinedTable> join(String qrToken, {String? name}) async {
    calls.add('join');
    joinCount += 1;
    return JoinedTable(
      guestToken: 'guest-$joinCount',
      label: 'Guest $joinCount',
      sessionId: 's1',
      code: 'A12-1',
    );
  }

  @override
  Future<TableSnapshot> state(String guestToken) async {
    calls.add('state:$guestToken');
    if (guestToken == deadToken) throw 'Session closed';
    return snapshot;
  }

  @override
  Future<TableOrder> placeOrder(
    String guestToken,
    List<TableCartLine> lines, {
    String notes = '',
  }) async {
    calls.add('order');
    lastLines = lines;
    return _order();
  }

  @override
  Future<void> submitRating(String guestToken, RatingDraft draft) async {
    calls.add('rating');
    lastDraft = draft;
    snapshot = _snapshot(hasRated: true);
  }
}

void main() {
  group('QR table wire models', () {
    test('resolve payload maps restaurant, table and session', () {
      final context = TableContext.fromJson({
        'restaurant': {
          'id': 'r1',
          'slug': 'tavo',
          'name': {'en': 'Tavo', 'ar': 'تافو'},
          'logo': {'imageUrl': 'https://cdn/logo.png'},
        },
        'table': {'id': 't1', 'code': 'A12', 'zone': 'Terrace', 'seats': 4},
        'session': {'guestCount': 2},
      });

      expect(context.restaurantName, 'Tavo');
      expect(context.restaurantNameAr, 'تافو');
      expect(context.tableCode, 'A12');
      expect(context.seats, 4);
      expect(context.hasActiveSession, isTrue);
      expect(context.guestCount, 2);
    });

    test('session payload survives missing optionals and string numbers', () {
      final snapshot = TableSnapshot.fromJson({
        'session': {
          'id': 's1',
          'code': 'A12-1',
          'guestCount': '2',
          'guests': [
            {'label': 'Guest 1'},
            {'label': ''},
          ],
        },
        'orders': [
          {
            'id': 'o1',
            'orderNumber': 1042,
            'status': 'preparing',
            'items': [
              {
                'name': 'Kabsa',
                'quantity': '2',
                'unitPrice': '50',
                'lineTotal': '100',
                'specifications': [
                  {'name': 'extra rice'},
                ],
                'addedByGuestId': 'g1',
              },
            ],
            'subtotal': '100',
            'tax': '15',
            'total': '115',
            'addedByMe': true,
          },
        ],
      });

      expect(snapshot.guestCount, 2);
      expect(snapshot.guests, ['Guest 1']);
      expect(snapshot.bill.total, 0, reason: 'no bill block → safe defaults');
      expect(snapshot.orders.single.orderNumber, '1042');
      expect(snapshot.orders.single.items.single.quantity, 2);
      expect(
        snapshot.orders.single.items.single.specifications,
        ['extra rice'],
      );
      expect(snapshot.orders.single.addedByMe, isTrue);
      expect(snapshot.canOrder, isTrue);
      expect(snapshot.hasRated, isFalse);
    });

    test('rating draft omits empty comment, waiter message and non-review scores', () {
      const draft = RatingDraft(
        type: 'complaint',
        scores: {},
        comment: '  cold food  ',
        waiterMessage: '   ',
      );

      expect(draft.toJson(), {'type': 'complaint', 'comment': 'cold food'});
    });
  });

  group('TableSessionCubit', () {
    test('joins a fresh table, persists the token and exposes the party', () async {
      final repo = _FakeRepo();
      final store = _MemoryStore();
      final cubit = TableSessionCubit(repo, store, qrToken: 'qr-1');

      await cubit.open();

      final state = cubit.state as TableSessionReady;
      expect(state.context.tableCode, 'A12');
      expect(state.snapshot.myLabel, 'Guest 1');
      expect(repo.calls, ['resolve', 'join', 'state:guest-1']);
      expect(store.saved['qr-1'], 'guest-1');
      await cubit.close();
    });

    test('resumes a stored guest instead of re-joining the table', () async {
      final repo = _FakeRepo();
      final store = _MemoryStore()..saved['qr-1'] = 'guest-9';
      final cubit = TableSessionCubit(repo, store, qrToken: 'qr-1');

      await cubit.open();

      expect(cubit.state, isA<TableSessionReady>());
      expect(repo.joinCount, 0);
      expect(repo.calls, ['resolve', 'state:guest-9']);
      await cubit.close();
    });

    test('a dead stored session is replaced by a fresh join', () async {
      final repo = _FakeRepo()..deadToken = 'guest-old';
      final store = _MemoryStore()..saved['qr-1'] = 'guest-old';
      final cubit = TableSessionCubit(repo, store, qrToken: 'qr-1');

      await cubit.open();

      expect(repo.joinCount, 1);
      expect(store.saved['qr-1'], 'guest-1');
      expect(cubit.state, isA<TableSessionReady>());
      await cubit.close();
    });

    test('a failed resolve becomes a retryable failure', () async {
      final repo = _FakeRepo()..resolveError = 'Table not found';
      final cubit = TableSessionCubit(repo, _MemoryStore(), qrToken: 'qr-1');

      await cubit.open();

      expect((cubit.state as TableSessionFailure).message, 'Table not found');
      expect(repo.joinCount, 0);
      await cubit.close();
    });
  });

  group('cart and shared ordering', () {
    test('tapping add twice makes one line of two, not two lines', () async {
      final cubit = TableSessionCubit(
        _FakeRepo(),
        _MemoryStore(),
        qrToken: 'qr-1',
      );
      await cubit.open();

      cubit.addItem(id: 'm1', name: 'Kabsa', price: 50);
      cubit.addItem(id: 'm1', name: 'Kabsa', price: 50);

      var state = cubit.state as TableSessionReady;
      expect(state.cart.length, 1);
      expect(state.cartCount, 2);
      expect(state.cartTotal, 100);

      cubit.decrementItem('m1');
      cubit.decrementItem('m1');
      state = cubit.state as TableSessionReady;
      expect(state.cart, isEmpty);

      await cubit.close();
    });

    test('placing an order sends the cart and clears it', () async {
      final repo = _FakeRepo();
      final cubit = TableSessionCubit(repo, _MemoryStore(), qrToken: 'qr-1');
      await cubit.open();

      cubit.addItem(id: 'm1', name: 'Kabsa', price: 50);
      final sent = await cubit.placeOrder(notes: 'no onions');

      expect(sent, isTrue);
      final state = cubit.state as TableSessionReady;
      expect(state.cart, isEmpty);
      expect(state.placing, isFalse);
      expect(repo.calls, contains('order'));
      expect(repo.lastLines.single.menuItemId, 'm1');
      expect(repo.lastLines.single.quantity, 1);
      await cubit.close();
    });

    test('a rejected order keeps the cart so the guest can retry', () async {
      final repo = _RejectingRepo();
      final cubit = TableSessionCubit(repo, _MemoryStore(), qrToken: 'qr-1');
      await cubit.open();

      cubit.addItem(id: 'm1', name: 'Kabsa', price: 50);
      final sent = await cubit.placeOrder();

      expect(sent, isFalse);
      final state = cubit.state as TableSessionReady;
      expect(state.cartCount, 1, reason: 'the guest must not lose the cart');
      expect(state.actionError, 'Item is unavailable');
      await cubit.close();
    });
  });

  group('experience rating', () {
    test('submitting a review forwards the five areas and flips hasRated', () async {
      final repo = _FakeRepo();
      final cubit = TableSessionCubit(repo, _MemoryStore(), qrToken: 'qr-1');
      await cubit.open();

      final sent = await cubit.submitRating(
        const RatingDraft(
          type: 'review',
          scores: {
            'restaurant': 5,
            'waiter': 4,
            'food': 5,
            'speed': 3,
            'cleanliness': 5,
          },
          comment: 'Lovely evening',
          waiterMessage: 'Ask for Omar',
        ),
      );

      expect(sent, isTrue);
      expect(repo.lastDraft?.scores['waiter'], 4);
      expect(repo.lastDraft?.waiterMessage, 'Ask for Omar');
      expect((cubit.state as TableSessionReady).snapshot.hasRated, isTrue);
      await cubit.close();
    });
  });

  group('/t/<token> deep link', () {
    test('a printed table link opens the table session', () {
      final target = DeepLinkService.parse(
        'https://tavo.abwabdigital.com/t/AbCdEfGhIjKlMnOpQrStUvWx',
      );

      expect(
        target,
        const TableSessionTarget('AbCdEfGhIjKlMnOpQrStUvWx'),
      );
      expect(target?.tableToken, 'AbCdEfGhIjKlMnOpQrStUvWx');
      expect(target?.restaurantId, isNull);
    });

    test('the short web demo path is not a table token', () {
      expect(
        DeepLinkService.parse('https://tavo.abwabdigital.com/t/5'),
        DeepLinkTarget.none,
      );
    });

    test('a look-alike host is rejected', () {
      expect(
        DeepLinkService.parse(
          'https://tavo.abwabdigital.com.evil.com/t/AbCdEfGhIjKlMnOpQrStUvWx',
        ),
        DeepLinkTarget.none,
      );
    });

    test('the menu deep link still works', () {
      final target = DeepLinkService.parse(
        'https://tavo.abwabdigital.com/menu/tavo',
      );
      expect(target?.slug, 'tavo');
      expect(target?.tableToken, isNull);
    });
  });
}

class _RejectingRepo extends _FakeRepo {
  @override
  Future<TableOrder> placeOrder(
    String guestToken,
    List<TableCartLine> lines, {
    String notes = '',
  }) async {
    throw 'Item is unavailable';
  }
}
