// lib/feature/panel_invoice/ui/logic/invoice_panel_state.dart
import '../../data/model/invoice_models.dart';

/// States of the staff panel's invoice view.
///
/// Mirrors `OrdersState`: plain classes, plain-string errors.
sealed class InvoicePanelState {
  const InvoicePanelState();
}

class InvoicePanelInitial extends InvoicePanelState {
  const InvoicePanelInitial();
}

class InvoicePanelLoading extends InvoicePanelState {
  const InvoicePanelLoading();
}

class InvoicePanelLoaded extends InvoicePanelState {
  const InvoicePanelLoaded(this.invoice);

  final PanelInvoice invoice;
}

class InvoicePanelError extends InvoicePanelState {
  const InvoicePanelError(this.message);

  final String message;
}
