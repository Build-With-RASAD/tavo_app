// lib/feature/panel_invoice/ui/logic/invoice_panel_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/panel_invoice/data/repo/invoice_panel_repo.dart';

import 'invoice_panel_state.dart';

export 'invoice_panel_state.dart';

/// Staff panel invoice: loads one ZATCA invoice for an order.
///
/// Error style mirrors `OrdersCubit` (plain strings). `load` always emits
/// [InvoicePanelLoading] first, so retry from [InvoicePanelError] re-shows
/// the skeleton before the fresh result.
class InvoicePanelCubit extends Cubit<InvoicePanelState> {
  InvoicePanelCubit(this._repo, {required this.restaurantId})
      : super(const InvoicePanelInitial());

  final InvoicePanelRepo _repo;
  final String restaurantId;

  Future<void> load(String orderId) async {
    if (isClosed) return;
    emit(const InvoicePanelLoading());
    try {
      final invoice = await _repo.getInvoice(orderId, restaurantId);
      if (isClosed) return;
      emit(InvoicePanelLoaded(invoice));
    } catch (e) {
      if (isClosed) return;
      emit(InvoicePanelError(_message(e)));
    }
  }

  String _message(dynamic error) =>
      error is String ? error : error.toString();
}
