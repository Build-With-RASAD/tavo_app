// ui/logic/staff_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/staff_models.dart';
import '../../data/repo/staff_panel_repo.dart';

part 'staff_panel_state.dart';

/// Staff panel's team list: add by phone, edit role/permissions, suspend /
/// activate and delete.
///
/// Error style mirrors `OrdersCubit` (plain strings): `load` failures emit
/// [StaffPanelError]; mutation failures keep the loaded list and surface a
/// transient [StaffPanelLoaded.actionError] beside it. Suspending drops the
/// row locally to mirror the backend list filter (suspended members are
/// excluded from `GET /staff`).
class StaffPanelCubit extends Cubit<StaffPanelState> {
  StaffPanelCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const StaffPanelInitial());

  final StaffPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const StaffPanelLoading());
    try {
      final members = await _repo.getStaff(restaurantId);
      if (isClosed) return;
      emit(StaffPanelLoaded(members: members));
    } catch (e) {
      if (isClosed) return;
      emit(StaffPanelError(_message(e)));
    }
  }

  Future<void> addStaff({
    required String phone,
    required String name,
    required String role,
    required List<String> permissions,
  }) async {
    final s = state;
    if (s is! StaffPanelLoaded) return;
    try {
      final created = await _repo.addStaff(
        restaurantId: restaurantId,
        phone: phone,
        name: name,
        role: role,
        permissions: permissions,
      );
      if (isClosed) return;
      emit(s.copyWith(members: [...s.members, created], clearError: true));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e)));
    }
  }

  Future<void> saveStaff(
    PanelStaffMember member, {
    String? role,
    List<String>? permissions,
  }) async {
    final s = state;
    if (s is! StaffPanelLoaded) return;
    emit(s.copyWith(actionId: member.id, clearError: true));
    try {
      final saved = await _repo.updateStaff(
        restaurantId: restaurantId,
        id: member.id,
        role: role,
        permissions: permissions,
      );
      if (isClosed) return;
      emit(s.copyWith(
        members: [
          for (final m in s.members)
            if (m.id == member.id) saved else m,
        ],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> setStatus(PanelStaffMember member, String status) async {
    final s = state;
    if (s is! StaffPanelLoaded) return;
    emit(s.copyWith(actionId: member.id, clearError: true));
    try {
      final saved = await _repo.updateStaff(
        restaurantId: restaurantId,
        id: member.id,
        status: status,
      );
      if (isClosed) return;
      // The backend list filter excludes suspended members, so a suspend
      // drops the row locally; anything else (activate) swaps it in place.
      emit(s.copyWith(
        members: status == 'suspended'
            ? s.members.where((m) => m.id != member.id).toList()
            : [
                for (final m in s.members)
                  if (m.id == member.id) saved else m,
              ],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  Future<void> removeStaff(PanelStaffMember member) async {
    final s = state;
    if (s is! StaffPanelLoaded) return;
    emit(s.copyWith(actionId: member.id, clearError: true));
    try {
      await _repo.deleteStaff(restaurantId: restaurantId, id: member.id);
      if (isClosed) return;
      emit(s.copyWith(
        members: s.members.where((m) => m.id != member.id).toList(),
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
