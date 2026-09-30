// lib/feature/panel_invoice/di/register_invoice_module.dart
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/panel_invoice/data/repo/invoice_panel_repo.dart';
import 'package:tavo/feature/panel_invoice/ui/logic/invoice_panel_cubit.dart';

/// Reported to the controller as the service_locator.dart one-liner pair:
///   import 'package:tavo/feature/panel_invoice/di/register_invoice_module.dart';
///   registerInvoiceModule();
///
/// Registers [InvoicePanelRepo] (lazy singleton) and the [InvoicePanelCubit]
/// factory (param1 = restaurantId, mirroring `OrdersCubit`). Both guards
/// make re-runs safe.
void registerInvoiceModule() {
  if (!getIt.isRegistered<InvoicePanelRepo>()) {
    getIt.registerLazySingleton<InvoicePanelRepo>(
      () => InvoicePanelRepo(getIt<ApiService>()),
    );
  }
  if (!getIt.isRegistered<InvoicePanelCubit>()) {
    getIt.registerFactoryParam<InvoicePanelCubit, String, void>(
      (restaurantId, _) => InvoicePanelCubit(
        getIt<InvoicePanelRepo>(),
        restaurantId: restaurantId,
      ),
    );
  }
}
