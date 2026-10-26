// test/panel_menu_test.dart
//
// The menu module's contract, end to end below the HTTP layer:
//
//   • models: bilingual specification pairing (by key, then position),
//     `status` decoding, and the payload that writes both languages plus
//     availability in ONE request;
//   • cubit: server-side category/status/search filters, debounced typing,
//     counts probed with `limit=1`, and mutations that re-read instead of
//     guessing the new page;
//   • screen: list default with a grid toggle, role gating, category manager,
//     the delete confirmation, and the read-only sheet for view-only staff.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/data/repo/menu_panel_repo.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';
import 'package:tavo/feature/panel_menu/ui/screens/panel_menu_screen.dart';
import 'package:tavo/feature/panel_menu/ui/widgets/menu_widgets.dart';

import 'helpers/app_shell.dart';

const _manager = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'owner',
  permissions: ['full_access'],
  status: 'active',
);

/// View-only staff: the `requirePermission`-mirroring gate must hide writes.
const _viewer = StaffRestaurant(
  restaurantId: 'r1',
  name: 'Burger Lab',
  nameEn: 'Burger Lab',
  nameAr: 'برغر لاب',
  role: 'staff',
  permissions: ['view_menu'],
  status: 'active',
);

PanelMenuCategory _cat(String id, String ar, String en, {int items = 0}) =>
    PanelMenuCategory(id: id, arName: ar, enName: en, itemCount: items);

PanelMenuItem _item(
  String id,
  String categoryId,
  String ar,
  String en,
  double price, {
  bool active = true,
  String arDescription = '',
  String enDescription = '',
  List<PanelMenuSpecification> specifications = const [],
  String? imageUrl,
}) =>
    PanelMenuItem(
      id: id,
      categoryId: categoryId,
      arName: ar,
      enName: en,
      price: price,
      active: active,
      arDescription: arDescription,
      enDescription: enDescription,
      specifications: specifications,
      imageUrl: imageUrl,
    );

/// Fake repo: canned rows, a call journal and the exact filter arguments of
/// every read. Filters are applied here the way the server applies them, so
/// a client-side filter regression cannot pass.
class _FakeRepo extends MenuPanelRepo {
  _FakeRepo() : super(api: ApiService());

  List<PanelMenuCategory> categories = <PanelMenuCategory>[];
  List<PanelMenuItem> items = <PanelMenuItem>[];
  Object? failure;
  final List<String> calls = <String>[];
  final List<
      ({
        int page,
        int limit,
        String? categoryId,
        String? status,
        String? search
      })> reads = <
      ({
        int page,
        int limit,
        String? categoryId,
        String? status,
        String? search
      })>[];

  /// The last *list* read. `reads.last` is usually a `limit=1` count probe,
  /// which carries the same filters but is a different request.
  ({
    int page,
    int limit,
    String? categoryId,
    String? status,
    String? search
  }) get lastPageRead =>
      reads.lastWhere((r) => r.limit == menuPageSize);
  final List<PanelMenuItemPayload> payloads = <PanelMenuItemPayload>[];

  /// Returned by create/update instead of echoing the payload, so a test can
  /// assert what the *server* decided (status, id) rather than what it sent.
  PanelMenuItem? nextSaved;

  @override
  Future<List<PanelMenuCategory>> getCategories(String restaurantId) async {
    calls.add('getCategories');
    _maybeThrow();
    return categories;
  }

  @override
  Future<({List<PanelMenuItem> items, int page, int pages, int total})>
      getItems(
    String restaurantId, {
    int page = 1,
    int limit = menuPageSize,
    String? categoryId,
    String? status,
    String? search,
  }) async {
    reads.add((
      page: page,
      limit: limit,
      categoryId: categoryId,
      status: status,
      search: search,
    ));
    calls.add('getItems');
    _maybeThrow();

    Iterable<PanelMenuItem> visible = items;
    if (categoryId != null) {
      visible = visible.where((PanelMenuItem i) => i.categoryId == categoryId);
    }
    if (status != null) {
      visible = visible.where(
        (PanelMenuItem i) => (i.active ? 'active' : 'inactive') == status,
      );
    }
    final String term = (search ?? '').trim().toLowerCase();
    if (term.isNotEmpty) {
      visible = visible.where((PanelMenuItem i) =>
          i.name('ar').toLowerCase().contains(term) ||
          i.name('en').toLowerCase().contains(term) ||
          i.description('ar').toLowerCase().contains(term) ||
          i.description('en').toLowerCase().contains(term));
    }

    final List<PanelMenuItem> all = visible.toList();
    final int pages = all.isEmpty ? 1 : (all.length / limit).ceil();
    final int start = (page - 1) * limit;
    return (
      items: all.skip(start).take(limit).toList(),
      page: page,
      pages: pages,
      total: all.length,
    );
  }

  @override
  Future<PanelMenuItem> createItem({
    required String restaurantId,
    required PanelMenuItemPayload payload,
  }) async {
    calls.add('createItem');
    payloads.add(payload);
    _maybeThrow();
    final PanelMenuItem saved = nextSaved ??
        _item(
          'm-new',
          payload.categoryId,
          payload.arName,
          payload.enName,
          payload.price,
          active: payload.active,
          specifications: payload.specifications,
        );
    items = <PanelMenuItem>[saved, ...items];
    return saved;
  }

  @override
  Future<PanelMenuItem> updateItem({
    required String restaurantId,
    required String id,
    required PanelMenuItemPayload payload,
  }) async {
    calls.add('updateItem:$id');
    payloads.add(payload);
    _maybeThrow();
    final PanelMenuItem saved = nextSaved ??
        _item(
          id,
          payload.categoryId,
          payload.arName,
          payload.enName,
          payload.price,
          active: payload.active,
          specifications: payload.specifications,
        );
    items = <PanelMenuItem>[
      for (final PanelMenuItem i in items) if (i.id == id) saved else i,
    ];
    return saved;
  }

  @override
  Future<PanelMenuItem> toggleStatus(String id, {String? restaurantId}) async {
    calls.add('toggleStatus:$id');
    _maybeThrow();
    final int at = items.indexWhere((PanelMenuItem i) => i.id == id);
    items[at] = items[at].copyWith(active: !items[at].active);
    return items[at];
  }

  @override
  Future<void> deleteItem(String id, {String? restaurantId}) async {
    calls.add('deleteItem:$id');
    _maybeThrow();
    items.removeWhere((PanelMenuItem i) => i.id == id);
  }

  @override
  Future<PanelMenuItem> uploadItemImage({
    required String restaurantId,
    required String id,
    required Uint8List bytes,
    required String filename,
  }) async {
    calls.add('uploadItemImage:$id:$filename');
    _maybeThrow();
    final int at = items.indexWhere((PanelMenuItem i) => i.id == id);
    items[at] = items[at].copyWith(imageUrl: 'https://cdn.test/$filename');
    return items[at];
  }

  @override
  Future<PanelMenuItem> removeItemImage({
    required String restaurantId,
    required String id,
  }) async {
    calls.add('removeItemImage:$id');
    _maybeThrow();
    final int at = items.indexWhere((PanelMenuItem i) => i.id == id);
    items[at] = items[at].copyWith(clearImage: true);
    return items[at];
  }

  @override
  Future<PanelMenuCategory> createCategory({
    required String restaurantId,
    required String arName,
    required String enName,
  }) async {
    calls.add('createCategory:$arName');
    _maybeThrow();
    final PanelMenuCategory created = _cat('c-new', arName, enName);
    categories = <PanelMenuCategory>[...categories, created];
    return created;
  }

  @override
  Future<PanelMenuCategory> updateCategory({
    required String restaurantId,
    required String id,
    required String arName,
    required String enName,
  }) async {
    calls.add('updateCategory:$id');
    _maybeThrow();
    final PanelMenuCategory renamed =
        _cat(id, arName, enName, items: _countOf(id));
    categories = <PanelMenuCategory>[
      for (final PanelMenuCategory c in categories)
        if (c.id == id) renamed else c,
    ];
    return renamed;
  }

  @override
  Future<void> deleteCategory(String id, {String? restaurantId}) async {
    calls.add('deleteCategory:$id');
    _maybeThrow();
    categories = categories.where((PanelMenuCategory c) => c.id != id).toList();
  }

  int _countOf(String categoryId) =>
      items.where((PanelMenuItem i) => i.categoryId == categoryId).length;

  /// One-shot: the next read/write fails, then the fake recovers.
  void _maybeThrow() {
    final Object? f = failure;
    if (f == null) return;
    failure = null;
    throw f;
  }
}

void main() {
  setUpAll(initTestEnv);

  group('specifications', () {
    test('pairs the two languages by key, not by position', () {
      final List<PanelMenuSpecification> specs =
          PanelMenuSpecification.fromLocales(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'size',
            'title': 'الحجم',
            'type': 'single',
            'required': true,
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'صغير', 'price': 0},
              <String, dynamic>{'title': 'كبير', 'price': 5},
            ],
          },
          <String, dynamic>{
            'key': 'dough',
            'title': 'العجينة',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'كلاسيك', 'price': 0},
            ],
          },
        ],
        <Map<String, dynamic>>[
          // Reversed on purpose: the server does not promise array order.
          <String, dynamic>{
            'key': 'dough',
            'title': 'Dough',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'Classic', 'price': 0},
            ],
          },
          <String, dynamic>{
            'key': 'size',
            'title': 'Size',
            'type': 'single',
            'required': true,
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'Small', 'price': 0},
              <String, dynamic>{'title': 'Large', 'price': 5},
            ],
          },
        ],
      );

      expect(specs, hasLength(2));
      final PanelMenuSpecification size =
          specs.firstWhere((PanelMenuSpecification s) => s.key == 'size');
      expect(size.arTitle, 'الحجم');
      expect(size.enTitle, 'Size');
      expect(size.type, 'single');
      expect(size.required, isTrue);
      expect(size.options, hasLength(2));
      expect(size.options[1].title('ar'), 'كبير');
      expect(size.options[1].title('en'), 'Large');
      expect(size.options[1].price, 5);

      final PanelMenuSpecification dough =
          specs.firstWhere((PanelMenuSpecification s) => s.key == 'dough');
      expect(dough.enTitle, 'Dough');
      expect(dough.arTitle, 'العجينة');
      expect(dough.required, isFalse);
    });

    test('falls back to position for legacy rows without keys', () {
      final List<PanelMenuSpecification> specs =
          PanelMenuSpecification.fromLocales(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'الحجم',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'صغير', 'price': 0},
            ],
          },
        ],
        <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Size',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'title': 'Small', 'price': 0},
            ],
          },
        ],
      );

      expect(specs, hasLength(1));
      expect(specs.single.key, '');
      expect(specs.single.arTitle, 'الحجم');
      expect(specs.single.enTitle, 'Size');
      expect(specs.single.options.single.title('en'), 'Small');
    });

    test('keeps an untranslated group editable instead of dropping it', () {
      final List<PanelMenuSpecification> specs =
          PanelMenuSpecification.fromLocales(
        <Map<String, dynamic>>[
          <String, dynamic>{'title': 'الحجم'},
          <String, dynamic>{'title': 'العجينة'},
        ],
        <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Size'},
        ],
      );

      expect(specs, hasLength(2));
      expect(specs[1].arTitle, 'العجينة');
      expect(specs[1].enTitle, '');
      expect(specs[1].isPublishable, isFalse);
    });
  });

  group('payload', () {
    PanelMenuSpecification size({bool complete = true}) =>
        PanelMenuSpecification(
          arTitle: 'الحجم',
          enTitle: 'Size',
          options: <PanelMenuOption>[
            const PanelMenuOption(arTitle: 'صغير', enTitle: 'Small'),
            PanelMenuOption(
              arTitle: 'كبير',
              enTitle: complete ? 'Large' : '',
              price: 5,
            ),
          ],
        );

    test('sends availability inside the same write', () {
      final Map<String, dynamic> active = PanelMenuItemPayload(
        categoryId: 'c1',
        arName: 'برجر',
        enName: 'Burger',
        price: 32,
      ).toJson();
      final Map<String, dynamic> hidden = PanelMenuItemPayload(
        categoryId: 'c1',
        arName: 'برجر',
        enName: 'Burger',
        price: 32,
        active: false,
      ).toJson();

      expect(active['status'], 'active');
      expect(hidden['status'], 'inactive');
      expect(active['categoryId'], 'c1');
    });

    test('derives spec keys from the English title and de-duplicates them',
        () {
      final PanelMenuItemPayload payload = PanelMenuItemPayload(
        categoryId: 'c1',
        arName: 'بيتزا',
        enName: 'Pizza',
        price: 40,
        specifications: <PanelMenuSpecification>[
          size(),
          size(),
        ],
      );
      final Map<String, dynamic> json = payload.toJson();

      final List<dynamic> arSpecs =
          (json['ar'] as Map<String, dynamic>)['specifications'] as List<dynamic>;
      final List<dynamic> enSpecs =
          (json['en'] as Map<String, dynamic>)['specifications'] as List<dynamic>;

      expect(arSpecs, hasLength(2));
      expect(enSpecs, hasLength(2));
      expect((arSpecs[0] as Map<String, dynamic>)['key'], 'size');
      expect((enSpecs[0] as Map<String, dynamic>)['key'], 'size');
      expect((arSpecs[1] as Map<String, dynamic>)['key'], 'size-2');
      expect((enSpecs[1] as Map<String, dynamic>)['key'], 'size-2');
      // Both languages list the same options in the same order.
      expect(((enSpecs[0] as Map<String, dynamic>)['options'] as List<dynamic>)
          .length, 2);
      expect(
        (((arSpecs[0] as Map<String, dynamic>)['options'] as List<dynamic>)[1]
            as Map<String, dynamic>)['price'],
        5,
      );
    });

    test('drops a half-translated group instead of publishing it', () {
      final PanelMenuItemPayload payload = PanelMenuItemPayload(
        categoryId: 'c1',
        arName: 'بيتزا',
        enName: 'Pizza',
        price: 40,
        specifications: <PanelMenuSpecification>[size(complete: false)],
      );
      final Map<String, dynamic> json = payload.toJson();

      expect(
        ((json['en'] as Map<String, dynamic>)['specifications'] as List<dynamic>),
        isEmpty,
      );
      expect(payload.publishableSpecifications, isEmpty);
    });

    test('decodes status, populated category and localized text', () {
      final PanelMenuItem item = PanelMenuItem.fromJson(<String, dynamic>{
        '_id': 'm1',
        'menuCategoryId': <String, dynamic>{'_id': 'c1', 'en': <String, dynamic>{'name': 'Burgers'}},
        'ar': <String, dynamic>{'name': 'برجر', 'description': 'لحم'},
        'en': <String, dynamic>{'name': 'Burger', 'description': 'Beef'},
        'price': '32.5',
        'status': 'inactive',
        'image': <String, dynamic>{'imageUrl': 'https://cdn.test/b.png'},
      });

      expect(item.id, 'm1');
      expect(item.categoryId, 'c1');
      expect(item.price, 32.5);
      expect(item.active, isFalse);
      expect(item.name('ar'), 'برجر');
      expect(item.description('en'), 'Beef');
      expect(item.imageUrl, 'https://cdn.test/b.png');
    });
  });

  group('cubit', () {
    test('loads categories, one page and both status counts', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 3)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28, active: false),
          _item('m3', 'c1', 'شاي', 'Tea', 9, active: false),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);

      await cubit.load();
      final PanelMenuLoaded state = cubit.state as PanelMenuLoaded;

      expect(state.items, hasLength(3));
      expect(state.activeCount, 1);
      expect(state.inactiveCount, 2);
      expect(state.allCount, 3);
      expect(state.countFor(PanelMenuStatusFilter.active), 1);
      expect(state.countFor(PanelMenuStatusFilter.all), 3);
      // Two `limit=1` probes, one per status — no arithmetic on the page.
      expect(
        repo.reads.where((r) => r.limit == 1).map((r) => r.status),
        containsAll(<String>['active', 'inactive']),
      );
    });

    test('category, status and search are all server filters', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[
          _cat('c1', 'برجر', 'Burgers', items: 1),
          _cat('c2', 'مشروبات', 'Drinks', items: 1),
        ]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c2', 'قهوة', 'Coffee', 10, active: false),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setCategory('c1');
      expect((cubit.state as PanelMenuLoaded).items.single.id, 'm1');
      expect(repo.lastPageRead.categoryId, 'c1');
      expect(repo.lastPageRead.page, 1);
      // The counts describe the filtered set, so they carry the category too.
      final Iterable<String?> scopedCounts = repo.reads
          .where((r) => r.limit == 1 && r.categoryId == 'c1')
          .map((r) => r.status);
      expect(scopedCounts, containsAll(<String>['active', 'inactive']));

      await cubit.setStatus(PanelMenuStatusFilter.inactive);
      final PanelMenuLoaded filtered = cubit.state as PanelMenuLoaded;
      expect(filtered.items, isEmpty); // Coffee is in the other category
      expect(repo.lastPageRead.status, 'inactive');
      expect(repo.lastPageRead.categoryId, 'c1');

      await cubit.clearFilters();
      cubit.setQuery('coffee');
      await cubit.submitSearch();
      expect((cubit.state as PanelMenuLoaded).items.single.id, 'm2');
      expect(repo.lastPageRead.search, 'coffee');
      expect(repo.lastPageRead.status, isNull);
      expect(repo.lastPageRead.categoryId, isNull);
    });

    test('typing is debounced into a single request', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers')]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
        searchDebounce: const Duration(milliseconds: 60),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final int before = repo.reads.length;

      cubit.setQuery('b');
      cubit.setQuery('bu');
      cubit.setQuery('bur');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.reads.length, before, reason: 'no request mid-typing');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.reads.length, greaterThan(before));
      expect(repo.lastPageRead.search, 'bur');
      expect(repo.lastPageRead.page, 1);
    });

    test('create sends one payload and re-reads page one', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers')]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();

      final bool ok = await cubit.saveItem(
        payload: const PanelMenuItemPayload(
          categoryId: 'c1',
          arName: 'شاي',
          enName: 'Tea',
          price: 9,
          active: false,
        ),
      );

      expect(ok, isTrue);
      expect(repo.calls, contains('createItem'));
      expect(repo.payloads.single.active, isFalse);
      expect(repo.lastPageRead.page, 1);
      final PanelMenuLoaded state = cubit.state as PanelMenuLoaded;
      expect(state.items.first.id, 'm-new');
      expect(state.items.first.active, isFalse);
      expect(state.saving, isFalse);
    });

    test('a failed save keeps the list and surfaces the reason', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers')]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();

      repo.failure = Exception('Price is required');
      final bool ok = await cubit.saveItem(
        payload: const PanelMenuItemPayload(
          categoryId: 'c1',
          arName: 'شاي',
          enName: 'Tea',
          price: 9,
        ),
      );

      expect(ok, isFalse);
      final PanelMenuLoaded state = cubit.state as PanelMenuLoaded;
      expect(state.actionError, 'Price is required');
      expect(state.items, hasLength(1));
      expect(state.saving, isFalse);
    });

    test('delete adjusts the row, the total and the category count', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 2)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28),
        ];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final PanelMenuItem target =
          (cubit.state as PanelMenuLoaded).items.first;

      await cubit.deleteItem(target);
      final PanelMenuLoaded state = cubit.state as PanelMenuLoaded;

      expect(state.items.where((i) => i.id == target.id), isEmpty);
      expect(state.total, 1);
      expect(state.categories.single.itemCount, 1);
    });

    test('a non-empty category is refused before the request', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 4)];
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final int callsBefore = repo.calls.length;

      final bool ok = await cubit.deleteCategory(
        (cubit.state as PanelMenuLoaded).categories.single,
      );

      expect(ok, isFalse);
      expect((cubit.state as PanelMenuLoaded).actionError,
          'category_not_empty');
      expect(repo.calls.length, callsBefore, reason: 'no request at all');
    });

    test('a load failure is reported, and retry recovers', () async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers')]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ]
        ..failure = Exception('Network down');
      final PanelMenuCubit cubit = PanelMenuCubit(
        repo,
        restaurantId: 'r1',
        canManage: () => true,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect((cubit.state as PanelMenuError).message, 'Network down');

      await cubit.load();
      expect(cubit.state, isA<PanelMenuLoaded>());
    });
  });

  group('screen', () {
    Future<void> pumpMenu(
      WidgetTester tester,
      _FakeRepo repo, {
      StaffRestaurant venue = _manager,
    }) async {
      tester.view.physicalSize = const Size(400, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appShell(PanelMenuScreen(
        restaurantId: 'r1',
        venue: venue,
        repo: repo,
        searchDebounce: const Duration(milliseconds: 50),
      )));
      await pumpUntil(
        tester,
        () => find.byType(MenuSkeletonList).evaluate().isNotEmpty ||
            find.byType(MenuItemRow).evaluate().isNotEmpty ||
            find.byType(MenuEmptyState).evaluate().isNotEmpty ||
            find.byType(MenuErrorState).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders dense rows with a real status per row',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[
          _cat('c1', 'برجر', 'Burgers', items: 2),
        ]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32,
              enDescription: 'Double patty'),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28, active: false),
        ];

      await pumpMenu(tester, repo);

      expect(find.byType(MenuItemRow), findsNWidgets(2));
      expect(find.text('Double Burger'), findsOneWidget);
      expect(find.text('Double patty'), findsOneWidget);
      expect(find.text('32 SAR'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('menu_status_m2')),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('menu_status_m2')),
          matching: find.text('Inactive'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the grid toggle is a real second layout',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 1)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];

      await pumpMenu(tester, repo);
      expect(find.byType(MenuItemRow), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('menu_view_grid')));
      await tester.pumpAndSettle();

      expect(find.byType(MenuItemTile), findsOneWidget);
      expect(find.byType(MenuItemRow), findsNothing);
    });

    testWidgets('status chips show server counts and refetch on tap',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[
          _cat('c1', 'برجر', 'Burgers', items: 3),
        ]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28, active: false),
          _item('m3', 'c1', 'شاي', 'Tea', 9, active: false),
        ];

      await pumpMenu(tester, repo);

      MenuFilterChip chip(String key) =>
          tester.widget<MenuFilterChip>(find.byKey(ValueKey<String>(key)));
      expect(chip('filter_all').count, 3);
      expect(chip('filter_active').count, 1);
      expect(chip('filter_inactive').count, 2);

      await tester.tap(find.byKey(const ValueKey<String>('filter_inactive')));
      await tester.pumpAndSettle();

      expect(repo.lastPageRead.status, 'inactive');
      expect(find.text('Double Burger'), findsNothing);
      expect(find.text('Cheese Burger'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
    });

    testWidgets('typing hits the server search and clearing restores the list',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 3)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28),
          _item('m3', 'c1', 'شاي', 'Tea', 9),
        ];

      await pumpMenu(tester, repo);
      await tester.enterText(
          find.byKey(const ValueKey<String>('menu_search')), 'tea');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(repo.lastPageRead.search, 'tea');
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Double Burger'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('menu_search_clear')));
      await tester.pumpAndSettle();

      expect(repo.lastPageRead.search, '');
      expect(find.text('Double Burger'), findsOneWidget);
    });

    testWidgets('no filter match explains itself and can be cleared',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 1)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];

      await pumpMenu(tester, repo);
      await tester.enterText(
          find.byKey(const ValueKey<String>('menu_search')), 'sushi');
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches these filters'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Double Burger'), findsOneWidget);
    });

    testWidgets('load failure keeps a retry path', (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()..failure = Exception('Network down');

      tester.view.physicalSize = const Size(400, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appShell(PanelMenuScreen(
        restaurantId: 'r1',
        venue: _manager,
        repo: repo,
      )));
      await pumpUntil(
        tester,
        () => find.byType(MenuErrorState).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load the menu'), findsOneWidget);
      expect(find.textContaining('Network down'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No categories yet'), findsOneWidget);
    });

    testWidgets('delete goes through a confirmation sheet',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 1)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];

      await pumpMenu(tester, repo);
      await tester.tap(find.byKey(const ValueKey<String>('menu_actions_m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete item'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('confirm_delete_item')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_item')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('deleteItem:m1'));
      expect(find.text('Double Burger'), findsNothing);
      expect(find.text('No menu items yet'), findsOneWidget);
    });

    testWidgets('read-only staff get no mutation controls and a read-only sheet',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[_cat('c1', 'برجر', 'Burgers', items: 1)]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
        ];

      await pumpMenu(tester, repo, venue: _viewer);

      expect(find.byKey(const ValueKey<String>('menu_add_item')), findsNothing);
      expect(find.byKey(const ValueKey<String>('manage_categories')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('menu_actions_m1')), findsNothing);
      expect(find.text('Double Burger'), findsOneWidget);

      await tester.tap(find.text('Double Burger'));
      await tester.pumpAndSettle();

      expect(find.text('Read only — you cannot edit the menu'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('menu_item_save')), findsNothing);
      expect(find.byKey(const ValueKey<String>('item_price')), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('the category manager creates and reports real counts',
        (WidgetTester tester) async {
      final _FakeRepo repo = _FakeRepo()
        ..categories = <PanelMenuCategory>[
          _cat('c1', 'برجر', 'Burgers', items: 2),
          _cat('c2', 'مشروبات', 'Drinks'),
        ]
        ..items = <PanelMenuItem>[
          _item('m1', 'c1', 'دبل برجر', 'Double Burger', 32),
          _item('m2', 'c1', 'شيز برجر', 'Cheese Burger', 28),
        ];

      await pumpMenu(tester, repo);
      await tester.tap(find.byKey(const ValueKey<String>('manage_categories')));
      await tester.pumpAndSettle();

      expect(find.text('2 items'), findsOneWidget);
      // A category that still holds dishes cannot be deleted.
      final IconButton blocked = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('category_delete_c1')),
      );
      expect(blocked.onPressed, isNull);
      final IconButton free = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('category_delete_c2')),
      );
      expect(free.onPressed, isNotNull);

      await tester.enterText(
          find.byKey(const ValueKey<String>('category_new_ar')), 'حلويات');
      await tester.enterText(
          find.byKey(const ValueKey<String>('category_new_en')), 'Desserts');
      await tester.tap(find.byKey(const ValueKey<String>('category_new_save')));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('createCategory:حلويات'));
      expect(find.byKey(const ValueKey<String>('category_row_c-new')),
          findsOneWidget);
    });
  });
}
