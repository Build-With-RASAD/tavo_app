// ui/logic/branches_panel_state.dart
part of 'branches_panel_cubit.dart';

sealed class BranchesPanelState {
  const BranchesPanelState();
}

class BranchesPanelInitial extends BranchesPanelState {
  const BranchesPanelInitial();
}

class BranchesPanelLoading extends BranchesPanelState {
  const BranchesPanelLoading();
}

class BranchesPanelLoaded extends BranchesPanelState {
  const BranchesPanelLoaded({
    required this.branches,
    this.actionId,
    this.actionError,
  });

  final List<PanelBranch> branches;
  final String? actionId; // per-row spinner target
  final String? actionError; // transient, keeps the list on screen

  BranchesPanelLoaded copyWith({
    List<PanelBranch>? branches,
    String? actionId,
    String? actionError,
    bool clearAction = false,
    bool clearError = false,
  }) =>
      BranchesPanelLoaded(
        branches: branches ?? this.branches,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
      );
}

class BranchesPanelError extends BranchesPanelState {
  const BranchesPanelError(this.message);
  final String message;
}
