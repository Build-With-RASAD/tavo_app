// ui/logic/tables_panel_state.dart
part of 'tables_panel_cubit.dart';

sealed class TablesPanelState {
  const TablesPanelState();
}

class TablesPanelInitial extends TablesPanelState {
  const TablesPanelInitial();
}

class TablesPanelLoading extends TablesPanelState {
  const TablesPanelLoading();
}

class TablesPanelLoaded extends TablesPanelState {
  const TablesPanelLoaded({
    required this.types,
    required this.tables,
    this.selectedTypeId,
    this.saving = false,
    this.creating = false,
    this.actionId,
    this.actionError,
  });

  final List<PanelTableType> types;
  final String? selectedTypeId;
  final List<PanelPhysicalTable> tables;
  final bool saving; // save-layout spinner target
  final bool creating; // add-table form spinner target (T28)
  final String? actionId; // per-table spinner target
  final String? actionError; // transient, keeps the editor on screen

  TablesPanelLoaded copyWith({
    List<PanelTableType>? types,
    String? selectedTypeId,
    List<PanelPhysicalTable>? tables,
    bool? saving,
    bool? creating,
    String? actionId,
    String? actionError,
    bool clearAction = false,
    bool clearError = false,
  }) =>
      TablesPanelLoaded(
        types: types ?? this.types,
        selectedTypeId: selectedTypeId ?? this.selectedTypeId,
        tables: tables ?? this.tables,
        saving: saving ?? this.saving,
        creating: creating ?? this.creating,
        actionId: clearAction ? null : actionId ?? this.actionId,
        actionError: clearError ? null : actionError ?? this.actionError,
      );
}

class TablesPanelError extends TablesPanelState {
  const TablesPanelError(this.message);
  final String message;
}
