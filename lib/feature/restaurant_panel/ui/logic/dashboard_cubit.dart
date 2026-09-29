import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'dashboard_state.dart';

/// Staff panel home: loads [DashboardStats] for one venue on demand.
/// Mirrors `RestaurantHomeCubit` — loading first, plain-string errors via
/// [_message] so the UI treats panel and reservations failures identically.
class DashboardCubit extends Cubit<DashboardState> {
  final RestaurantPanelRepo _repo;

  DashboardCubit(this._repo) : super(DashboardInitial());

  Future<void> load(String restaurantId) async {
    emit(DashboardLoading());
    try {
      final stats = await _repo.getDashboard(restaurantId);
      emit(DashboardLoaded(stats));
    } catch (e) {
      emit(DashboardError(_message(e)));
    }
  }

  String _message(dynamic error) =>
      error is String ? error : error.toString();
}
