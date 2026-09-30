// ui/logic/settings_panel_state.dart
part of 'settings_panel_cubit.dart';

sealed class SettingsPanelState {
  const SettingsPanelState();
}

class SettingsPanelInitial extends SettingsPanelState {
  const SettingsPanelInitial();
}

class SettingsPanelLoading extends SettingsPanelState {
  const SettingsPanelLoading();
}

class SettingsPanelLoaded extends SettingsPanelState {
  const SettingsPanelLoaded({
    required this.days,
    required this.rs,
    required this.availability,
    this.saving = false,
    this.actionError,
  });

  final List<WorkingDayEntry> days;
  final ReservationSettings rs;
  final List<WorkingDayEntry> availability;
  final bool saving;
  final String? actionError;

  SettingsPanelLoaded copyWith({
    List<WorkingDayEntry>? days,
    ReservationSettings? rs,
    List<WorkingDayEntry>? availability,
    bool? saving,
    String? actionError,
    bool clearError = false,
  }) =>
      SettingsPanelLoaded(
        days: days ?? this.days,
        rs: rs ?? this.rs,
        availability: availability ?? this.availability,
        saving: saving ?? this.saving,
        actionError: clearError ? null : actionError ?? this.actionError,
      );
}

class SettingsPanelError extends SettingsPanelState {
  const SettingsPanelError(this.message);
  final String message;
}
