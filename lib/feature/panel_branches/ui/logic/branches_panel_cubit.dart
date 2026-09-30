// ui/logic/branches_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/branch_models.dart';
import '../../data/repo/branches_panel_repo.dart';

part 'branches_panel_state.dart';

/// Branches panel: branch cards with a 7-day hours editor, activate /
/// deactivate toggles and soft delete (the backend list keeps inactive rows,
/// so delete replaces the row in place instead of dropping it).
///
/// Error style mirrors `StaffPanelCubit` (plain strings): `load` failures
/// emit [BranchesPanelError]; mutation failures keep the loaded list and
/// surface a transient [BranchesPanelLoaded.actionError] beside it.
class BranchesPanelCubit extends Cubit<BranchesPanelState> {
  BranchesPanelCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const BranchesPanelInitial());

  final BranchesPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const BranchesPanelLoading());
    try {
      final branches = await _repo.getBranches(restaurantId);
      if (isClosed) return;
      emit(BranchesPanelLoaded(branches: branches));
    } catch (e) {
      if (isClosed) return;
      emit(BranchesPanelError(_message(e)));
    }
  }

  /// Creates when [id] is null, updates otherwise.
  Future<void> save({
    String? id,
    required String arName,
    required String enName,
    required String address,
    required String city,
    required String region,
    required List<String> phones,
    String? email,
    String? whatsapp,
    double? latitude,
    double? longitude,
    required Map<String, Map<String, dynamic>> workingHours,
    String? managerName,
  }) async {
    final s = state;
    if (s is! BranchesPanelLoaded) return;
    if (id != null) {
      emit(s.copyWith(actionId: id, clearError: true));
    }
    try {
      if (id == null) {
        final created = await _repo.createBranch(
          restaurantId: restaurantId,
          arName: arName,
          enName: enName,
          address: address,
          city: city,
          region: region,
          phones: phones,
          email: email,
          whatsapp: whatsapp,
          latitude: latitude,
          longitude: longitude,
          workingHours: workingHours,
          managerName: managerName,
        );
        if (isClosed) return;
        emit(s.copyWith(
          branches: [...s.branches, created],
          clearError: true,
        ));
      } else {
        final saved = await _repo.updateBranch(
          restaurantId: restaurantId,
          id: id,
          arName: arName,
          enName: enName,
          address: address,
          city: city,
          region: region,
          phones: phones,
          email: email,
          whatsapp: whatsapp,
          latitude: latitude,
          longitude: longitude,
          workingHours: workingHours,
          managerName: managerName,
        );
        if (isClosed) return;
        emit(s.copyWith(
          branches: [
            for (final b in s.branches) if (b.id == id) saved else b,
          ],
          clearAction: true,
        ));
      }
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Flips `isActive` in place; failures keep the row.
  Future<void> setActive(PanelBranch branch, bool active) async {
    final s = state;
    if (s is! BranchesPanelLoaded) return;
    emit(s.copyWith(actionId: branch.id, clearError: true));
    try {
      final saved = await _repo.updateBranch(
        restaurantId: restaurantId,
        id: branch.id,
        isActive: active,
      );
      if (isClosed) return;
      emit(s.copyWith(
        branches: [
          for (final b in s.branches) if (b.id == branch.id) saved else b,
        ],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  /// Soft delete: the backend keeps the row with `isActive:false`, so the
  /// row is replaced with the returned body instead of dropped.
  Future<void> remove(PanelBranch branch) async {
    final s = state;
    if (s is! BranchesPanelLoaded) return;
    emit(s.copyWith(actionId: branch.id, clearError: true));
    try {
      final deleted = await _repo.deleteBranch(
        restaurantId: restaurantId,
        id: branch.id,
      );
      if (isClosed) return;
      emit(s.copyWith(
        branches: [
          for (final b in s.branches) if (b.id == branch.id) deleted else b,
        ],
        clearAction: true,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(s.copyWith(actionError: _message(e), clearAction: true));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
