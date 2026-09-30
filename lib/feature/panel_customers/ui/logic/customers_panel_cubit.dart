// ui/logic/customers_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/customer_models.dart';
import '../../data/repo/customers_panel_repo.dart';

part 'customers_panel_state.dart';

/// Staff panel customers list: server-side search, page navigation and
/// row-tap detail loading (the detail itself lives in [CustomerDetailCubit]).
///
/// Error style mirrors `ReviewsPanelCubit` (plain strings): `load` failures
/// emit [CustomersPanelError]; reload failures (search / paging) also emit
/// [CustomersPanelError] since the loaded state carries no transient slot.
class CustomersPanelCubit extends Cubit<CustomersPanelState> {
  CustomersPanelCubit(this._repo, {required this.restaurantId})
      : super(const CustomersPanelInitial());

  final CustomersPanelRepo _repo;
  final String restaurantId;

  Future<void> load() async {
    if (isClosed) return;
    emit(const CustomersPanelLoading());
    try {
      final out = await _repo.getCustomers(restaurantId);
      if (isClosed) return;
      emit(CustomersPanelLoaded(
        customers: out.customers,
        page: out.page,
        pages: out.pages,
        total: out.total,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(CustomersPanelError(_message(e)));
    }
  }

  /// Server-side search (empty = clear filter): refetches from page 1.
  Future<void> search(String query) async {
    final s = state;
    if (s is! CustomersPanelLoaded || s.search == query) return;
    emit(s.copyWith(search: query, clearSearch: query.isEmpty));
    await _reload(page: 1);
  }

  Future<void> goToPage(int page) async {
    final s = state;
    if (s is! CustomersPanelLoaded || page < 1 || page > s.pages) return;
    await _reload(page: page);
  }

  Future<void> _reload({int? page}) async {
    final s = state;
    if (s is! CustomersPanelLoaded) return;
    try {
      final out = await _repo.getCustomers(
        restaurantId,
        page: page ?? s.page,
        search: s.search,
      );
      if (isClosed) return;
      emit(s.copyWith(
        customers: out.customers,
        page: out.page,
        pages: out.pages,
        total: out.total,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(CustomersPanelError(_message(e)));
    }
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
