// test/panel_reservations_test.dart
//
// Wave 1 Task 13: reservations tab migrated to the panel API.
// `RestaurantHomeCubit` reads the panel reservations endpoints through
// `RestaurantPanelRepo`; constructor shape and public
// `loadReservations()`/`updateStatus(id, action)` names are unchanged.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_state.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/reservations_tab.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';

import 'helpers/app_shell.dart';

Map<String, dynamic> _panelRow({required String id, required String status}) => {
      '_id': id,
      'restaurantId': {
        '_id': 'r1',
        'ar': {'name': 'برغر لاب'},
        'en': {'name': 'Burger Lab'},
      },
      'startAt': '2026-10-01T19:00:00.000Z',
      'endAt': '2026-10-01T21:00:00.000Z',
      'guestsCount': 2,
      'status': status,
      'customer': {'name': 'Noura Said', 'phone': '+966501112233'},
      'specialRequests': '',
      'createdAt': '2026-09-30T10:00:00.000Z',
    };

String _next(String action) => switch (action) {
      'confirm' => 'confirmed',
      'seat' => 'seated',
      'complete' => 'completed',
      'cancel' => 'cancelled',
      _ => action,
    };

/// Panel-shaped fake: raw maps (mirroring the populated Reservation docs the
/// panel returns) mapped through the real `BookingModel.fromJson`.
class _FakePanelRepo extends RestaurantPanelRepo {
  _FakePanelRepo() : super(ApiService());
  List<Map<String, dynamic>> raw = [];
  Object? failure;
  final List<String> calls = [];

  @override
  Future<List<BookingModel>> getReservations(String restaurantId,
      {int limit = 100}) async {
    calls.add('getReservations:$restaurantId:$limit');
    _maybeThrow();
    return raw.map(BookingModel.fromJson).toList();
  }

  @override
  Future<BookingModel> updateReservationAction(
      {required String restaurantId,
      required String id,
      required String action,
      String? reason}) async {
    calls.add('update:$id:$action:${reason ?? '-'}');
    _maybeThrow();
    final i = raw.indexWhere((r) => r['_id'] == id);
    raw[i] = {...raw[i], 'status': _next(action)};
    return BookingModel.fromJson(raw[i]);
  }

  void _maybeThrow() {
    if (failure != null) {
      final f = failure;
      failure = null;
      throw f!;
    }
  }
}

void main() {
  setUpAll(initTestEnv);

  test('load hits the panel endpoint with limit=100 and emits rows',
      () async {
    final repo = _FakePanelRepo()
      ..raw = [_panelRow(id: 'm1', status: 'pending')];
    final cubit = RestaurantHomeCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);

    await cubit.loadReservations();

    expect(repo.calls, contains('getReservations:r1:100'));
    final state = cubit.state as RestaurantHomeLoaded;
    expect(state.reservations, hasLength(1));
    expect(state.reservations.single.guestName, 'Noura Said');
    expect(state.reservations.single.status, 'pending');
  });

  test('load failure emits the error state', () async {
    final repo = _FakePanelRepo()..failure = Exception('panel down');
    final cubit = RestaurantHomeCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);

    await cubit.loadReservations();

    expect(cubit.state, isA<RestaurantHomeError>());
  });

  test('updateStatus confirm swaps the row through the panel action',
      () async {
    final repo = _FakePanelRepo()
      ..raw = [_panelRow(id: 'm1', status: 'pending')];
    final cubit = RestaurantHomeCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.loadReservations();

    await cubit.updateStatus('m1', 'confirm');

    expect(repo.calls, contains('update:m1:confirm:-'));
    final state = cubit.state as RestaurantHomeLoaded;
    expect(state.reservations.single.status, 'confirmed');
    expect(state.actingId, isNull); // spinner cleared
  });

  test('updateStatus failure keeps the list and surfaces actionError',
      () async {
    final repo = _FakePanelRepo()
      ..raw = [_panelRow(id: 'm1', status: 'pending')];
    final cubit = RestaurantHomeCubit(repo, restaurantId: 'r1');
    addTearDown(cubit.close);
    await cubit.loadReservations();
    repo.failure = Exception('illegal transition');

    await cubit.updateStatus('m1', 'complete');

    final state = cubit.state as RestaurantHomeLoaded;
    expect(state.reservations, hasLength(1));
    expect(state.reservations.single.status, 'pending'); // unchanged
    expect(state.actionError, contains('illegal transition'));
  });

  testWidgets('reservations tab renders panel rows for the venue',
      (tester) async {
    final repo = _FakePanelRepo()
      ..raw = [_panelRow(id: 'm1', status: 'pending')];
    GetIt.instance.registerFactoryParam<RestaurantHomeCubit, String, void>(
      (restaurantId, _) =>
          RestaurantHomeCubit(repo, restaurantId: restaurantId),
    );
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(appShell(const ReservationsTab(restaurantId: 'r1')));
    await tester.pumpAndSettle();

    expect(find.text('Noura Said'), findsOneWidget);
    expect(repo.calls, contains('getReservations:r1:100'));
  });
}
