// ui/logic/settings_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/settings_models.dart';
import '../../data/repo/settings_panel_repo.dart';

part 'settings_panel_state.dart';

/// Staff panel settings: working hours, reservation rules and the
/// read-only availability summary.
///
/// Error style mirrors `PanelMenuCubit` (plain strings): `load` failures
/// emit [SettingsPanelError]; save failures keep the form and surface a
/// transient [SettingsPanelLoaded.actionError] beside it.
class SettingsPanelCubit extends Cubit<SettingsPanelState> {
  SettingsPanelCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const SettingsPanelInitial());

  final SettingsPanelRepo _repo;
  final String restaurantId;

  /// Backend may omit days; seed [kWeekDays] defaults so the form always
  /// renders all 7 rows.
  List<WorkingDayEntry> _seedDefaults(List<WorkingDayEntry> backend) {
    final byDay = {for (final d in backend) d.day: d};
    return [
      for (final day in kWeekDays)
        byDay[day] ?? WorkingDayEntry(day: day),
    ];
  }

  Future<void> load() async {
    if (isClosed) return;
    emit(const SettingsPanelLoading());
    try {
      final results = await Future.wait([
        _repo.getSettings(restaurantId),
        _repo.getAvailability(restaurantId),
      ]);
      if (isClosed) return;
      final settings = results[0] as ({
        List<WorkingDayEntry> workingHours,
        ReservationSettings reservationSettings,
        Map<String, dynamic> celebrationFeatures
      });
      final availability = results[1] as ({
        ReservationSettings reservationSettings,
        List<WorkingDayEntry> workingHours
      });
      emit(SettingsPanelLoaded(
        days: _seedDefaults(settings.workingHours),
        rs: settings.reservationSettings,
        availability: availability.workingHours.isEmpty
            ? _seedDefaults(settings.workingHours)
            : _seedDefaults(availability.workingHours),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(SettingsPanelError(_message(e)));
    }
  }

  Future<void> saveWorkingHours(List<WorkingDayEntry> days) async {
    final s = state;
    if (s is! SettingsPanelLoaded || s.saving) return;
    emit(s.copyWith(saving: true, clearError: true));
    try {
      final saved = await _repo.updateWorkingHours(restaurantId, days);
      if (isClosed) return;
      emit(s.copyWith(
        days: _seedDefaults(saved),
        availability: _seedDefaults(saved),
        saving: false,
        clearError: true,
        lastSavedAt: DateTime.now(),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(saving: false, actionError: _message(e)));
    }
  }

  Future<void> saveReservationSettings(ReservationSettings rs) async {
    final s = state;
    if (s is! SettingsPanelLoaded || s.saving) return;
    emit(s.copyWith(saving: true, clearError: true));
    try {
      final saved = await _repo.updateReservationSettings(restaurantId, rs);
      if (isClosed) return;
      emit(s.copyWith(
        rs: saved,
        saving: false,
        clearError: true,
        lastSavedAt: DateTime.now(),
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(saving: false, actionError: _message(e)));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
