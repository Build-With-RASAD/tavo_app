// lib/feature/panel_invoice/data/model/invoice_models.dart
//
// ZATCA invoice payload for `GET /orders/:id/invoice` (Task 25 backend).
//
// Tolerant of missing keys: strings default to `''`, numbers to `0`.
// `zatcaQr` / `vatNumber` are nullable — the backend sends `null` for both
// when the venue has no VAT number (then the UI shows the VAT hint, NO QR).
class InvoiceLine {
  const InvoiceLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int qty;
  final double unitPrice;
  final double lineTotal;

  /// Accepts both `qty` (invoice service shape) and `quantity` (order
  /// schema shape) so the model never silently zeroes a line.
  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      name: json['name']?.toString() ?? '',
      qty: _toInt(json['qty'] ?? json['quantity']),
      unitPrice: _toDouble(json['unitPrice']),
      lineTotal: _toDouble(json['lineTotal']),
    );
  }
}

class PanelInvoice {
  const PanelInvoice({
    required this.invoiceNumber,
    required this.invoiceNo,
    required this.items,
    required this.subtotal,
    required this.vatAmount,
    required this.total,
    required this.issuedAt,
    required this.restaurantName,
    required this.vatNumber,
    required this.zatcaQr,
  });

  final int invoiceNumber;
  final String invoiceNo;
  final List<InvoiceLine> items;
  final double subtotal;
  final double vatAmount;
  final double total;
  final String issuedAt;
  final String restaurantName;

  /// `null` when the venue has no VAT number (backend omits the QR too).
  final String? vatNumber;

  /// Backend-built base64 TLV (ZATCA tags 1-5). Rendered VERBATIM — never
  /// recomputed client-side (single source of truth).
  final String? zatcaQr;

  factory PanelInvoice.fromJson(Map<String, dynamic> json) {
    final restaurant =
        json['restaurant'] is Map ? Map<String, dynamic>.from(
              json['restaurant'] as Map,
            ) : const <String, dynamic>{};
    final rawItems = json['items'] ?? json['menuItems'];
    return PanelInvoice(
      invoiceNumber: _toInt(json['invoiceNumber']),
      invoiceNo: json['invoiceNo']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .map(
                (e) => InvoiceLine.fromJson(
                  e is Map ? Map<String, dynamic>.from(e) : const <String, dynamic>{},
                ),
              )
              .toList()
          : const [],
      subtotal: _toDouble(json['subtotal']),
      vatAmount: _toDouble(json['vatAmount'] ?? json['tax']),
      total: _toDouble(json['total'] ?? json['totalPrice']),
      issuedAt: json['issuedAt']?.toString() ?? '',
      restaurantName:
          restaurant['name']?.toString() ?? json['seller']?.toString() ?? '',
      vatNumber: restaurant['vatNumber']?.toString() ?? json['vatNumber']?.toString(),
      zatcaQr: json['zatcaQr']?.toString(),
    );
  }

  /// TEXT share body (`ShareParams(text:)` + clipboard fallback — no file,
  /// no path_provider). Print carries the full PDF instead.
  String shareSummary() => 'Invoice $invoiceNo — ${_compact(total)} SAR';

  static String _compact(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

int _toInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

double _toDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;
