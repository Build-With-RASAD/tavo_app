// test/order_card_line_note_test.dart
//
// Kitchen line notes are per dish, not per order. A guest asking for "no
// onions" on one kabsa must not turn into an order-level note that appears
// over the tea as well.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/ui/widgets/order_card.dart';

import 'helpers/app_shell.dart';

void main() {
  setUpAll(initTestEnv);

  testWidgets('renders a note directly under its dish line', (tester) async {
    final order = PanelOrder(
      id: 'o1',
      orderNumber: '42',
      customerName: 'Nora',
      customerPhone: '',
      items: const [
        OrderLine(
          name: 'Kabsa',
          quantity: 1,
          unitPrice: 50,
          lineTotal: 50,
          note: 'No onions',
        ),
        OrderLine(name: 'Tea', quantity: 1, unitPrice: 5, lineTotal: 5),
      ],
      subtotal: 55,
      tax: 8.25,
      totalPrice: 63.25,
      paymentStatus: 'unpaid',
      orderStatus: 'pending',
      createdAt: '2026-10-24T20:00:00.000Z',
      tableCode: 'A12',
      source: 'qr_table',
    );

    await tester.pumpWidget(
      appShell(
        Scaffold(
          body: SingleChildScrollView(
            child: OrderCard(
              order: order,
              acting: false,
              onAction: (_) {},
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No onions'), findsOneWidget);
    expect(find.text('Kabsa'), findsOneWidget);
    expect(find.text('Tea'), findsOneWidget);
  });
}
