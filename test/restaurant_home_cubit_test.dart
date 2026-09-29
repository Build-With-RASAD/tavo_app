import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_state.dart';

class FakeHomeRepo extends RestaurantAuthRepo {
  FakeHomeRepo() : super(ApiService());

  List<BookingModel> reservations = [];
  Object? loadError;
  String? failActionFor;
  int loadCalls = 0;

  @override
  Future<List<BookingModel>> getRestaurantReservations(
      String restaurantId) async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    return reservations;
  }

  @override
  Future<BookingModel> updateReservationStatus({
    required String id,
    required String action,
    String? reason,
  }) async {
    if (failActionFor == id) throw 'Server error';
    final current =
        reservations.firstWhere((b) => b.id == id, orElse: () => throw 'gone');
    const next = {
      'confirm': 'confirmed',
      'seat': 'seated',
      'complete': 'completed',
      'cancel': 'cancelled',
    };
    final updated = BookingModel(
      id: current.id,
      startAt: current.startAt,
      endAt: current.endAt,
      createdAt: current.createdAt,
      status: next[action] ?? current.status,
      guestsCount: current.guestsCount,
      restaurantNameEn: current.restaurantNameEn,
    );
    reservations = [
      for (final b in reservations) b.id == id ? updated : b,
    ];
    return updated;
  }
}

BookingModel _booking({required String id, String status = 'pending'}) =>
    BookingModel(
      id: id,
      startAt: DateTime(2026, 10, 1, 19, 30),
      endAt: DateTime(2026, 10, 1, 21, 30),
      createdAt: '2026-09-29',
      restaurantNameEn: 'Burger Lab',
      guestsCount: 4,
      status: status,
    );

void main() {
  late FakeHomeRepo repo;
  late RestaurantHomeCubit cubit;

  setUp(() {
    repo = FakeHomeRepo();
    cubit = RestaurantHomeCubit(repo, restaurantId: 'r1');
  });

  tearDown(() => cubit.close());

  test('load emits Loaded with the restaurant reservations', () async {
    repo.reservations = [_booking(id: 'a'), _booking(id: 'b')];

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantHomeLoading>(),
        predicate<RestaurantHomeLoaded>(
          (s) => s.reservations.map((b) => b.id).join() == 'ab',
        ),
      ]),
    );
    await cubit.loadReservations();
    await expectation;

    expect(repo.loadCalls, 1);
  });

  test('load failure emits Error', () async {
    repo.loadError = 'No internet connection';

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantHomeLoading>(),
        isA<RestaurantHomeError>(),
      ]),
    );
    await cubit.loadReservations();
    await expectation;
  });

  test('confirm flips a pending row to confirmed', () async {
    repo.reservations = [_booking(id: 'a')];
    await cubit.loadReservations();

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        predicate<RestaurantHomeLoaded>((s) => s.actingId == 'a'),
        predicate<RestaurantHomeLoaded>(
          (s) =>
              s.actingId == null &&
              s.reservations.single.status == 'confirmed',
        ),
      ]),
    );
    await cubit.updateStatus('a', 'confirm');
    await expectation;
  });

  test('failed action keeps the list and surfaces the error', () async {
    repo.reservations = [_booking(id: 'a')];
    repo.failActionFor = 'a';
    await cubit.loadReservations();

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        predicate<RestaurantHomeLoaded>((s) => s.actingId == 'a'),
        predicate<RestaurantHomeLoaded>(
          (s) =>
              s.actingId == null &&
              s.reservations.single.status == 'pending' &&
              (s.actionError ?? '').contains('Server error'),
        ),
      ]),
    );
    await cubit.updateStatus('a', 'confirm');
    await expectation;
  });
}
