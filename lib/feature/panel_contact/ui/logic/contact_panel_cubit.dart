// ui/logic/contact_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/contact_models.dart';
import '../../data/repo/contact_panel_repo.dart';

part 'contact_panel_state.dart';

/// Staff panel contact settings: phone / email / whatsapp / social links /
/// bilingual description, plus the read-only menu link + QR.
///
/// Error style mirrors `SettingsPanelCubit` (plain strings): `load`
/// failures emit [ContactPanelError]; save failures keep the form and
/// surface a transient [ContactPanelLoaded.actionError] beside it, while a
/// successful save flips [ContactPanelLoaded.justSaved] so the screen can
/// show the `contact_saved` confirmation once.
class ContactPanelCubit extends Cubit<ContactPanelState> {
  ContactPanelCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const ContactPanelInitial());

  final ContactPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const ContactPanelLoading());
    try {
      final contact = await _repo.getContact(restaurantId);
      if (isClosed) return;
      emit(ContactPanelLoaded(contact: contact));
    } catch (e) {
      if (isClosed) return;
      emit(ContactPanelError(_message(e)));
    }
  }

  Future<void> save({
    String? phone,
    String? email,
    String? whatsapp,
    Map<String, String>? socialLinks,
    String? descriptionAr,
    String? descriptionEn,
  }) async {
    final s = state;
    if (s is! ContactPanelLoaded || s.saving) return;
    emit(s.copyWith(saving: true, clearError: true, clearSaved: true));
    try {
      final saved = await _repo.updateContact(
        restaurantId: restaurantId,
        phone: phone,
        email: email,
        whatsapp: whatsapp,
        socialLinks: socialLinks,
        descriptionAr: descriptionAr,
        descriptionEn: descriptionEn,
      );
      if (isClosed) return;
      emit(s.copyWith(
        contact: saved,
        saving: false,
        clearError: true,
        justSaved: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(saving: false, actionError: _message(e)));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
