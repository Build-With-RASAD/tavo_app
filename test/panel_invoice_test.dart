// test/panel_invoice_test.dart
//
// Wave E2 Task 27: staff-panel ZATCA invoice (print + share).
//
// Binding rules pinned here:
//   * the QR renders DIRECTLY from the backend `zatcaQr` base64 string —
//     never recomputed client-side (single source of truth);
//   * no VAT number -> VAT hint, NO QR widget;
//   * share = TEXT summary + clipboard fallback (no path_provider);
//   * print carries the full PDF (fake actions in tests).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/panel_invoice/data/model/invoice_models.dart';
import 'package:tavo/feature/panel_invoice/data/repo/invoice_panel_repo.dart';
import 'package:tavo/feature/panel_invoice/ui/logic/invoice_panel_cubit.dart';
import 'package:tavo/feature/panel_invoice/ui/screens/panel_invoice_screen.dart';

import 'helpers/app_shell.dart';

/// Valid base64 (raw TLV-ish bytes) so `base64Decode` succeeds on screen.
final String _qrBase64 = base64Encode([1, 5, 104, 101, 108, 108, 111]);

Map<String, dynamic> _invoiceJson({bool withQr = true}) => {
      'invoiceNumber': 42,
      'invoiceNo': 'INV-000042',
      'items': [
        {
          'name': 'Smoky BBQ Burger',
          'qty': 2,
          'unitPrice': 32,
          'lineTotal': 64,
        },
        {'name': 'برجر', 'qty': 1, 'unitPrice': 20, 'lineTotal': 20},
      ],
      'subtotal': 84,
      'vatAmount': 12.6,
      'total': 96.6,
      'issuedAt': '2026-09-30T10:00:00.000Z',
      'restaurant': {
        'name': 'Burger Lab',
        'vatNumber': withQr ? '300123456700003' : null,
      },
      'zatcaQr': withQr ? _qrBase64 : null,
    };

PanelInvoice _invoice({bool withQr = true}) =>
    PanelInvoice.fromJson(_invoiceJson(withQr: withQr));

class _FakeApi extends ApiService {
  dynamic getResponse;
  Object? getError;
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    if (getError != null) throw getError!;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: getResponse,
    );
  }
}

class _FakeInvoiceRepo extends InvoicePanelRepo {
  _FakeInvoiceRepo() : super(ApiService());

  PanelInvoice? invoice;
  Object? failure;
  int calls = 0;

  @override
  Future<PanelInvoice> getInvoice(String orderId, String restaurantId) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failure != null) {
      final f = failure!;
      failure = null;
      throw f;
    }
    return invoice!;
  }
}

class _FakeInvoiceActions implements InvoiceActions {
  int prints = 0;
  int shares = 0;
  PanelInvoice? lastPrinted;
  PanelInvoice? lastShared;

  @override
  Future<void> printInvoice(PanelInvoice invoice) async {
    prints++;
    lastPrinted = invoice;
  }

  @override
  Future<void> shareInvoice(BuildContext context, PanelInvoice invoice) async {
    shares++;
    lastShared = invoice;
  }
}

Future<void> _pumpInvoice(
  WidgetTester tester,
  _FakeInvoiceRepo repo,
  _FakeInvoiceActions actions, {
  String orderId = 'o1',
}) async {
  final getIt = GetIt.instance;
  getIt.registerFactory<InvoicePanelRepo>(() => repo);
  getIt.registerFactoryParam<InvoicePanelCubit, String, void>(
    (restaurantId, _) =>
        InvoicePanelCubit(repo, restaurantId: restaurantId),
  );
  addTearDown(getIt.reset);
  await tester.pumpWidget(
    appShell(
      PanelInvoiceScreen(
        orderId: orderId,
        restaurantId: 'r1',
        actions: actions,
      ),
    ),
  );
}

void main() {
  setUpAll(initTestEnv);

  group('repo', () {
    test('getInvoice hits the invoice path and parses the full payload',
        () async {
      final api = _FakeApi();
      final repo = InvoicePanelRepo(api);
      api.getResponse = {'success': true, 'data': _invoiceJson()};

      final invoice = await repo.getInvoice('o1', 'r1');

      expect(api.lastGetPath, '/v1/api/restaurant-owner/orders/o1/invoice');
      expect(api.lastGetQuery!['restaurantId'], 'r1',
          reason: 'backend silently falls back to the FIRST venue without it');
      expect(invoice.invoiceNo, 'INV-000042');
      expect(invoice.invoiceNumber, 42);
      expect(invoice.items, hasLength(2));
      expect(invoice.items.first.qty, 2);
      expect(invoice.subtotal, 84);
      expect(invoice.vatAmount, 12.6);
      expect(invoice.total, 96.6);
      expect(invoice.restaurantName, 'Burger Lab');
      expect(invoice.vatNumber, '300123456700003');
      expect(invoice.zatcaQr, _qrBase64);
    });

    test('getInvoice parses a null-QR payload (no VAT number)', () async {
      final api = _FakeApi();
      final repo = InvoicePanelRepo(api);
      api.getResponse = {
        'success': true,
        'data': _invoiceJson(withQr: false),
      };

      final invoice = await repo.getInvoice('o1', 'r1');

      expect(invoice.zatcaQr, isNull);
      expect(invoice.vatNumber, isNull);
      expect(invoice.total, 96.6);
    });

    test('getInvoice throws a readable error on a missing payload', () async {
      final api = _FakeApi();
      final repo = InvoicePanelRepo(api);
      api.getResponse = {'success': false};

      expect(repo.getInvoice('o1', 'r1'), throwsA('Empty response'));
    });

    test('model tolerates the backend `quantity` line key', () {      final invoice = PanelInvoice.fromJson({
        ..._invoiceJson(),
        'items': [
          {
            'name': 'Fries',
            'quantity': 3,
            'unitPrice': 10,
            'lineTotal': 30,
          },
        ],
      });
      expect(invoice.items.single.qty, 3);
    });

    test('buildInvoicePdf produces a non-empty PDF for the print path',
        () async {
      final bytes = await buildInvoicePdf(_invoice());
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('buildInvoicePdf works without logo and without QR', () async {
      final bytes = await buildInvoicePdf(_invoice(withQr: false));
      expect(bytes, isNotEmpty);
    });
  });

  group('cubit', () {
    test('emits loading then loaded', () async {
      final repo = _FakeInvoiceRepo()..invoice = _invoice();
      final cubit = InvoicePanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      expect(cubit.state, isA<InvoicePanelInitial>());
      final future = cubit.load('o1');
      expect(cubit.state, isA<InvoicePanelLoading>());
      await future;

      final loaded = cubit.state as InvoicePanelLoaded;
      expect(loaded.invoice.invoiceNo, 'INV-000042');
    });

    test('emits error and retries', () async {
      final repo = _FakeInvoiceRepo()..failure = 'No internet connection';
      final cubit = InvoicePanelCubit(repo, restaurantId: 'r1');
      addTearDown(cubit.close);

      await cubit.load('o1');
      expect(cubit.state, isA<InvoicePanelError>());

      repo
        ..failure = null
        ..invoice = _invoice();
      await cubit.load('o1');
      expect(cubit.state, isA<InvoicePanelLoaded>());
    });
  });

  group('screen', () {
    testWidgets('renders logo, totals and the backend QR verbatim',
        (tester) async {
      final repo = _FakeInvoiceRepo()..invoice = _invoice();
      final actions = _FakeInvoiceActions();
      await _pumpInvoice(tester, repo, actions);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Header: orange-on-white app logo + restaurant name.
      expect(find.byKey(const ValueKey('invoice_logo')), findsOneWidget);
      expect(find.text('Burger Lab'), findsOneWidget);
      expect(find.text('INV-000042'), findsOneWidget);
      // Items + totals.
      expect(find.text('Smoky BBQ Burger'), findsOneWidget);
      expect(find.text('96.60'), findsWidgets);
      // Single-source QR: exactly one QR widget, built from the backend
      // base64 (the construction site passes `zatcaQr` verbatim — see the
      // `invoice_qr` widget; qr_flutter keeps its data field private so the
      // verbatim pin lives at the construction call + this presence pin).
      expect(find.byKey(const ValueKey('invoice_qr')), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      // Round-trip guard: the fixture base64 must decode (the screen calls
      // base64Decode on it — a malformed fixture would throw here too).
      expect(base64Decode(_qrBase64), isNotEmpty);
    });

    testWidgets('no VAT number shows the hint and NO QR', (tester) async {
      final repo = _FakeInvoiceRepo()..invoice = _invoice(withQr: false);
      await _pumpInvoice(tester, repo, _FakeInvoiceActions());
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.text('Add a VAT number to enable the ZATCA QR'),
        findsOneWidget,
      );
    });

    testWidgets('Print and Share call the injected actions', (tester) async {
      final repo = _FakeInvoiceRepo()..invoice = _invoice();
      final actions = _FakeInvoiceActions();
      await _pumpInvoice(tester, repo, actions);
      await tester.pumpAndSettle();

      // The action row sits below the fold in the 800x600 test viewport.
      final printBtn = find.byKey(const ValueKey('invoice_print'));
      final shareBtn = find.byKey(const ValueKey('invoice_share'));
      await tester.ensureVisible(printBtn);
      await tester.pumpAndSettle();
      await tester.tap(printBtn);
      await tester.ensureVisible(shareBtn);
      await tester.pumpAndSettle();
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(actions.prints, 1);
      expect(actions.shares, 1);
      expect(actions.lastPrinted?.invoiceNo, 'INV-000042');
      expect(actions.lastShared?.invoiceNo, 'INV-000042');
      expect(tester.takeException(), isNull);
    });

    testWidgets('error shows retry and retry reloads', (tester) async {
      final repo = _FakeInvoiceRepo()..failure = 'No internet connection';
      await _pumpInvoice(tester, repo, _FakeInvoiceActions());
      await tester.pumpAndSettle();

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byType(ListSkeleton), findsNothing);

      repo
        ..failure = null
        ..invoice = _invoice();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('INV-000042'), findsOneWidget);
    });
  });
}
