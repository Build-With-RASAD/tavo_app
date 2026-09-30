// ui/logic/contact_panel_state.dart
part of 'contact_panel_cubit.dart';

sealed class ContactPanelState {
  const ContactPanelState();
}

class ContactPanelInitial extends ContactPanelState {
  const ContactPanelInitial();
}

class ContactPanelLoading extends ContactPanelState {
  const ContactPanelLoading();
}

class ContactPanelLoaded extends ContactPanelState {
  const ContactPanelLoaded({
    required this.contact,
    this.saving = false,
    this.actionError,
    this.justSaved = false,
  });

  final PanelContact contact;
  final bool saving;
  final String? actionError;

  /// True on the single state emitted by a successful [ContactPanelCubit.save]
  /// so the screen can show the `contact_saved` confirmation once.
  final bool justSaved;

  ContactPanelLoaded copyWith({
    PanelContact? contact,
    bool? saving,
    String? actionError,
    bool clearError = false,
    bool? justSaved,
    bool clearSaved = false,
  }) =>
      ContactPanelLoaded(
        contact: contact ?? this.contact,
        saving: saving ?? this.saving,
        actionError: clearError ? null : actionError ?? this.actionError,
        justSaved: clearSaved ? false : justSaved ?? this.justSaved,
      );
}

class ContactPanelError extends ContactPanelState {
  const ContactPanelError(this.message);
  final String message;
}
