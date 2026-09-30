// ui/logic/customers_panel_state.dart
part of 'customers_panel_cubit.dart';

sealed class CustomersPanelState {
  const CustomersPanelState();
}

class CustomersPanelInitial extends CustomersPanelState {
  const CustomersPanelInitial();
}

class CustomersPanelLoading extends CustomersPanelState {
  const CustomersPanelLoading();
}

class CustomersPanelLoaded extends CustomersPanelState {
  const CustomersPanelLoaded({
    required this.customers,
    required this.page,
    required this.pages,
    required this.total,
    this.search,
  });

  final List<PanelCustomer> customers;
  final int page;
  final int pages;
  final int total;

  /// Active server-side search query (`null`/empty = no `&search=` param).
  final String? search;

  CustomersPanelLoaded copyWith({
    List<PanelCustomer>? customers,
    int? page,
    int? pages,
    int? total,
    String? search,
    bool clearSearch = false,
  }) =>
      CustomersPanelLoaded(
        customers: customers ?? this.customers,
        page: page ?? this.page,
        pages: pages ?? this.pages,
        total: total ?? this.total,
        // `search: ''` must clear the filter, so clearing is an explicit
        // flag rather than the nullable value itself.
        search: clearSearch ? null : search ?? this.search,
      );
}

class CustomersPanelError extends CustomersPanelState {
  const CustomersPanelError(this.message);
  final String message;
}
