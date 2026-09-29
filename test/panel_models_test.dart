// test/panel_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/restaurant_panel/data/model/dashboard_stats.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/data/model/paged_result.dart';

const _dashboard = {
  'orders': {
    'total': 12, 'pending': 3, 'confirmed': 2, 'preparing': 1, 'ready': 1,
    'delivered': 4, 'cancelled': 1, 'newOrders': [{}], 'avgOrderValue': 55.2,
  },
  'reservations': {
    'total': 8, 'pending': 2, 'confirmed': 3, 'seated': 1,
    'completed': 1, 'noShow': 0, 'cancelled': 1,
  },
  'revenue': {'total': 1234.5, 'thisMonth': 400},
  'reviews': {
    'averageRating': 4.6,
    'recent': [
      {
        '_id': 'r1', 'rating': 5, 'comment': 'Great!',
        'createdAt': '2026-09-06T10:43:00.000Z',
        'user': {'name': 'سعد السبيعي'},
      },
    ],
  },
};

const _order = {
  '_id': '6a9e23d92204c5061230acde',
  'orderNumber': 'ORD-2026-0155',
  'userId': {'_id': 'u1', 'phone': '+966515033695', 'name': 'سعد السبيعي'},
  'customer': {'name': '', 'phone': '', 'email': ''},
  'menuItems': [
    {'menuItemId': 'm1', 'name': 'Smoky BBQ Burger', 'quantity': 3,
     'unitPrice': 32, 'lineTotal': 96},
  ],
  'subtotal': 96, 'tax': 14.4, 'totalPrice': 110.4,
  'paymentStatus': 'paid', 'orderStatus': 'cancelled',
  'createdAt': '2026-09-01T11:52:00.000Z',
};

void main() {
  test('DashboardStats parses counts, revenue and recent reviews', () {
    final s = DashboardStats.fromJson(_dashboard);

    expect(s.orders.total, 12);
    expect(s.orders.newCount, 1);          // newOrders list tolerated as count source
    expect(s.orders.avgOrderValue, 55.2);
    expect(s.reservations.seated, 1);
    expect(s.revenue.thisMonth, 400);
    expect(s.reviews.averageRating, 4.6);
    expect(s.reviews.recent.single.userName, 'سعد السبيعي');
    expect(s.reviews.recent.single.comment, 'Great!');
  });

  test('DashboardStats survives missing sections without throwing', () {
    final s = DashboardStats.fromJson(const {});

    expect(s.orders.total, 0);
    expect(s.reviews.recent, isEmpty);
    expect(s.reviews.averageRating, 0);
  });

  test('PanelOrder prefers populated userId over empty customer', () {
    final o = PanelOrder.fromJson(_order);

    expect(o.id, '6a9e23d92204c5061230acde');
    expect(o.orderNumber, 'ORD-2026-0155');
    expect(o.customerName, 'سعد السبيعي');
    expect(o.customerPhone, '+966515033695');
    expect(o.orderStatus, 'cancelled');
    expect(o.items.single.lineTotal, 96);
    expect(o.totalPrice, 110.4);
  });

  test('PanelOrder falls back to customer block when userId absent', () {
    final o = PanelOrder.fromJson({
      ..._order,
      'userId': null,
      'customer': {'name': 'Walk-in', 'phone': '+966500000000'},
    });

    expect(o.customerName, 'Walk-in');
    expect(o.customerPhone, '+966500000000');
  });

  test('PanelOrder tolerates id/totalAmount/items key variants', () {
    final o = PanelOrder.fromJson({
      ..._order,
      '_id': null,
      'id': 'alt-id-1',
      'totalPrice': null,
      'totalAmount': 250.75,
      'menuItems': null,
      'items': [
        {'name': 'Alt Item', 'quantity': 2, 'unitPrice': 100, 'lineTotal': 200},
      ],
    });

    expect(o.id, 'alt-id-1');
    expect(o.totalPrice, 250.75);
    expect(o.items.single.name, 'Alt Item');
    expect(o.items.single.lineTotal, 200);
  });

  test('nextOrderActionsFor mirrors the backend transition map', () {
    expect(nextOrderActionsFor('pending'), ['confirmed', 'cancelled']);
    expect(nextOrderActionsFor('confirmed'), ['preparing', 'cancelled']);
    expect(nextOrderActionsFor('preparing'), ['ready', 'cancelled']);
    expect(nextOrderActionsFor('ready'), ['delivered', 'cancelled']);
    expect(nextOrderActionsFor('delivered'), isEmpty);
    expect(nextOrderActionsFor('cancelled'), isEmpty);
  });

  test('PagedResult.hasNext is page < pages', () {
    const r = PagedResult<int>(items: [1], page: 1, limit: 20, total: 40, pages: 2);
    expect(r.hasNext, isTrue);
  });
}
