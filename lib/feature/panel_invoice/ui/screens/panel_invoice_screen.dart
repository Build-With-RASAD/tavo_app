// lib/feature/panel_invoice/ui/screens/panel_invoice_screen.dart
//
// Staff-panel ZATCA invoice (print + share).
//
// Binding rules:
//   * The QR renders DIRECTLY from the backend `zatcaQr` base64 string —
//     never recomputed client-side. NOTE on the brief's literal call:
//     `QrImageView.data(data: base64Decode(...))` does NOT exist in the
//     pinned qr_flutter 4.1.0 (only `QrImageView(data: String)` and
//     `QrImageView.withQr`). The screen therefore passes the backend base64
//     STRING verbatim (`QrImageView(data: invoice.zatcaQr!)`) — the QR
//     content is still byte-for-byte the backend value, single source of
//     truth, ASCII-safe. The PDF likewise encodes the base64 string.
//   * No VAT number -> VAT hint, NO QR widget (backend sends null QR then).
//   * Share = TEXT summary (`ShareParams(text:)`) + clipboard fallback —
//     no path_provider. Print carries the full PDF.
//   * Arabic-PDF-glyph limitation: the `pdf` package embeds Helvetica by
//     default, which has no Arabic glyphs, so Arabic item names print as
//     blank/garbled in the PDF while totals + QR (the compliant core) are
//     ASCII-safe. The SCREEN is the bilingual source of truth; Task 22
//     triages embedding an Arabic TTF as follow-up.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/panel_invoice/data/model/invoice_models.dart';
import 'package:tavo/feature/panel_invoice/ui/logic/invoice_panel_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/widgets/order_card.dart'
    show formatOrderAmount;

/// Print/share seam: the screen calls these; tests inject a fake so no
/// platform plugin is ever touched in widget tests.
abstract class InvoiceActions {
  /// Prints the full A4 PDF (logo, items, totals, ZATCA QR).
  Future<void> printInvoice(PanelInvoice invoice);

  /// Shares the TEXT summary; falls back to the clipboard when the share
  /// plugin is unavailable (desktop / test runners).
  Future<void> shareInvoice(BuildContext context, PanelInvoice invoice);
}

/// Builds the A4 print PDF for [invoice].
///
/// Layout (binding): A4 portrait, logo top-start (Row order follows the
/// ambient [Directionality], so RTL puts it top-right), restaurant + VAT +
/// invoiceNo + issuedAt header block, items table (name/qty/price/total),
/// subtotal/VAT/total rows, QR bottom with the "ZATCA QR" caption encoding
/// the backend base64 TLV string verbatim. [logoBytes] is injectable so the
/// builder stays unit-testable without the asset bundle.
Future<Uint8List> buildInvoicePdf(
  PanelInvoice invoice, {
  Uint8List? logoBytes,
}) async {
  final doc = pw.Document();
  final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

  pw.Widget amountRow(String label, double value, {bool bold = false}) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(formatOrderAmount(value), style: style),
      ],
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: pdf.PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              if (logo != null) pw.Image(logo, width: 56, height: 56),
              if (logo != null) pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      invoice.restaurantName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if ((invoice.vatNumber ?? '').isNotEmpty)
                      pw.Text('VAT No: ${invoice.vatNumber}'),
                    pw.Text(invoice.invoiceNo),
                    pw.Text(invoice.issuedAt),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: const ['Item', 'Qty', 'Price', 'Total']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              for (final line in invoice.items)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(line.name),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${line.qty}'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(formatOrderAmount(line.unitPrice)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(formatOrderAmount(line.lineTotal)),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),
          amountRow('Subtotal', invoice.subtotal),
          amountRow('VAT', invoice.vatAmount),
          amountRow('Total', invoice.total, bold: true),
          if (invoice.zatcaQr != null) ...[
            pw.Spacer(),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.BarcodeWidget(
                    data: invoice.zatcaQr!,
                    barcode: pw.Barcode.qrCode(),
                    width: 160,
                    height: 160,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('ZATCA QR'),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  return doc.save();
}

class RealInvoiceActions implements InvoiceActions {
  @override
  Future<void> printInvoice(PanelInvoice invoice) async {
    Uint8List? logo;
    try {
      final data = await rootBundle.load('assets/icons/logo_icon.png');
      logo = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } catch (_) {
      // Logo is decorative — a missing asset must never block printing.
      logo = null;
    }
    final bytes = await buildInvoicePdf(invoice, logoBytes: logo);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: invoice.invoiceNo,
      format: pdf.PdfPageFormat.a4,
    );
  }

  @override
  Future<void> shareInvoice(
    BuildContext context,
    PanelInvoice invoice,
  ) async {
    final text = invoice.shareSummary();
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Desktop / test runners have no share plugin: fall back to the
      // clipboard so the summary is never silently lost.
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('inv_copied'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Staff invoice view for one order.
///
/// Builds its own [InvoicePanelCubit] through get_it (mirroring
/// `OrdersScreen`) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Print + Share go through the injectable
/// [InvoiceActions] ([RealInvoiceActions] in production, a fake in tests).
class PanelInvoiceScreen extends StatelessWidget {
  const PanelInvoiceScreen({
    super.key,
    required this.orderId,
    required this.restaurantId,
    this.actions,
  });

  final String orderId;
  final String restaurantId;
  final InvoiceActions? actions;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<InvoicePanelCubit>(param1: restaurantId)..load(orderId),
      child: BlocBuilder<InvoicePanelCubit, InvoicePanelState>(
        builder: (context, state) {
          final cubit = context.read<InvoicePanelCubit>();
          return Scaffold(
            appBar: AppBar(title: Text('inv_title'.tr())),
            body: SafeArea(
              child: _buildBody(context, cubit, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    InvoicePanelCubit cubit,
    InvoicePanelState state,
  ) {
    if (state is InvoicePanelError) {
      return ErrorStateView(
        message: state.message,
        onRetry: () => cubit.load(orderId),
      );
    }
    if (state is InvoicePanelLoaded) {
      return _LoadedInvoice(
        invoice: state.invoice,
        actions: actions ?? RealInvoiceActions(),
      );
    }
    // InvoicePanelInitial / InvoicePanelLoading.
    return const ListSkeleton();
  }
}

class _LoadedInvoice extends StatelessWidget {
  const _LoadedInvoice({required this.invoice, required this.actions});

  final PanelInvoice invoice;
  final InvoiceActions actions;

  @override
  Widget build(BuildContext context) {
    final vatNumber = invoice.vatNumber ?? '';
    final hasVat = vatNumber.isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Row order follows the ambient Directionality, so the
          // logo sits top-start (top-right in RTL) per the binding.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/icons/logo_icon.png',
                key: const ValueKey('invoice_logo'),
                height: 56,
                // Widget tests run without the asset bundle: never crash.
                errorBuilder: (_, __, ___) => SizedBox(height: 56.h),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.restaurantName,
                      style: TextStyles.font20Black500Weight(context),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      invoice.invoiceNo,
                      style: TextStyles.font12DarkGray400Weight(context),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${'inv_issued_at'.tr()}: ${invoice.issuedAt}',
                      style: TextStyles.font12DarkGray400Weight(context),
                    ),
                    SizedBox(height: 2.h),
                    // No VAT number -> VAT hint, NO QR (backend sends null
                    // QR then; the QR block below keys off `zatcaQr`).
                    Text(
                      hasVat
                          ? '${'inv_vat_no'.tr()}: $vatNumber'
                          : 'inv_add_vat_hint'.tr(),
                      style: TextStyles.font12DarkGray400Weight(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          for (final line in invoice.items) _LineRow(line: line),
          const Divider(height: 24),
          _AmountRow(labelKey: 'subtotal', value: invoice.subtotal),
          _AmountRow(labelKey: 'tax', value: invoice.vatAmount),
          _AmountRow(
            labelKey: 'total',
            value: invoice.total,
            emphasize: true,
          ),
          SizedBox(height: 16.h),
          // Single-source QR: the backend base64 TLV string, verbatim.
          // (qr_flutter 4.1.0 exposes no `.data(Uint8List)` constructor, so
          // the ASCII-safe base64 string form is used — same bytes out.)
          if (invoice.zatcaQr != null)
            Center(
              child: Column(
                children: [
                  QrImageView(
                    key: const ValueKey('invoice_qr'),
                    data: invoice.zatcaQr!,
                    version: QrVersions.auto,
                    size: 200,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'inv_zatca_qr'.tr(),
                    style: TextStyles.font12DarkGray400Weight(context),
                  ),
                ],
              ),
            ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('invoice_print'),
                  onPressed: () => actions.printInvoice(invoice),
                  icon: const Icon(Icons.print_outlined),
                  label: Text('inv_print'.tr()),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('invoice_share'),
                  onPressed: () => actions.shareInvoice(context, invoice),
                  icon: const Icon(Icons.share_outlined),
                  label: Text('inv_share'.tr()),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

/// One invoice line: name + `qty × unitPrice` on the left, line total right
/// (mirrors the orders details sheet).
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyles.font14Black400Weight(context),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${line.qty} × ${formatOrderAmount(line.unitPrice)}',
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            formatOrderAmount(line.lineTotal),
            style: TextStyles.font14Black500Weight(context),
          ),
        ],
      ),
    );
  }
}

/// One `label … amount` row (subtotal / tax / total).
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.labelKey,
    required this.value,
    this.emphasize = false,
  });

  final String labelKey;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? TextStyles.font16Black500Weight(context)
        : TextStyles.font14DarkGray400Weight(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Expanded(child: Text(labelKey.tr(), style: style)),
          Text(formatOrderAmount(value), style: style),
        ],
      ),
    );
  }
}
