// ui/logic/staff_panel_state.dart
part of 'staff_panel_cubit.dart';

sealed class StaffPanelState {
  const StaffPanelState();
}

class StaffPanelInitial extends StaffPanelState {
  const StaffPanelInitial();
}

class StaffPanelLoading extends StaffPanelState {
  const StaffPanelLoading();
}

class StaffPanelLoaded extends StaffPanelState {
  const StaffPanelLoaded({
    required this.members,
    this.actionId,
    this.actionError,
  });

  final List<PanelStaffMember> members;
  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the list on screen

  StaffPanelLoaded copyWith({
    List<PanelStaffMember>? members,
    String? actionId,
    String? actionError,
    bool clearAction = false,
    bool clearError = false,
  }) =>
      StaffPanelLoaded(
        members: members ?? this.members,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
      );
}

class StaffPanelError extends StaffPanelState {
  const StaffPanelError(this.message);
  final String message;
}
