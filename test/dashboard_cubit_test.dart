// test/dashboard_cubit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_state.dart';

class FakePanelRepo extends RestaurantPanelRepo {
  FakePanelRepo() : super(ApiService());
  DashboardStats? stats;
  Object? error;
  String? lastRestaurantId;

  @override
  Future<DashboardStats> getDashboard(String restaurantId) async {
    lastRestaurantId = restaurantId;
    if (error != null) throw error!;
    return stats!;
  }
}

void main() {
  late FakePanelRepo repo;
  late DashboardCubit cubit;

  setUp(() {
    repo = FakePanelRepo()
      ..stats = DashboardStats.fromJson(const {
        'orders': {'total': 7},
      });
    cubit = DashboardCubit(repo);
  });
  tearDown(() => cubit.close());

  test('load emits Loaded and passes the restaurant id through', () async {
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<DashboardLoading>(),
        predicate<DashboardLoaded>((s) => s.stats.orders.total == 7),
      ]),
    );
    await cubit.load('r2');
    await expectation;

    expect(repo.lastRestaurantId, 'r2');
  });

  test('load failure emits DashboardError with the message', () async {
    repo.error = 'No internet connection';

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([isA<DashboardLoading>(), isA<DashboardError>()]),
    );
    await cubit.load('r1');
    await expectation;
  });
}
