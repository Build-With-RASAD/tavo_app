// ui/logic/customer_detail_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/customer_models.dart';
import '../../data/repo/customers_panel_repo.dart';

sealed class CustomerDetailState {
  const CustomerDetailState();
}

class CustomerDetailInitial extends CustomerDetailState {
  const CustomerDetailInitial();
}

class CustomerDetailLoading extends CustomerDetailState {
  const CustomerDetailLoading();
}

class CustomerDetailLoaded extends CustomerDetailState {
  const CustomerDetailLoaded(this.detail);
  final PanelCustomerDetail detail;
}

class CustomerDetailError extends CustomerDetailState {
  const CustomerDetailError(this.message);
  final String message;
}

/// Loads one customer's profile + capped histories. The list screen awaits
/// [load] before pushing `CustomerDetailScreen`, so the detail screen itself
/// takes the loaded detail directly and has no loading state.
class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  CustomerDetailCubit(this._repo, {required this.restaurantId})
      : super(const CustomerDetailInitial());

  final CustomersPanelRepo _repo;
  final String restaurantId;

  Future<void> load(String key) async {
    if (isClosed) return;
    emit(const CustomerDetailLoading());
    try {
      final detail = await _repo.getCustomerDetail(restaurantId, key);
      if (isClosed) return;
      emit(CustomerDetailLoaded(detail));
    } catch (e) {
      if (isClosed) return;
      emit(CustomerDetailError(_message(e)));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
