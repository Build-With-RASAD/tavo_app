// test/restaurant_panel_repo_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';

class FakeApiService extends ApiService {
  dynamic getResponse;
  dynamic patchResponse;
  DioException? getError;
  DioException? patchError;
  String? lastGetPath;
  Map<String, dynamic>? lastGetQuery;
  String? lastPatchPath;
  dynamic lastPatchBody;

  @override
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters, Options? options}) async {
    lastGetPath = path;
    lastGetQuery = queryParameters;
    if (getError != null) throw getError!;
    return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: getResponse);
  }

  @override
  Future<Response> patch(String path,
      {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    lastPatchPath = path;
    lastPatchBody = data;
    if (patchError != null) throw patchError!;
    return Response(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: patchResponse);
  }
}

void main() {
  late FakeApiService api;
  late RestaurantPanelRepo repo;

  setUp(() {
    api = FakeApiService();
    repo = RestaurantPanelRepo(api);
  });

  test('getDashboard sends restaurantId and parses stats', () async {
    api.getResponse = {
      'success': true,
      'data': {
        'orders': {'total': 5},
        'reservations': {'total': 2},
        'revenue': {'total': 1, 'thisMonth': 2},
        'reviews': {'averageRating': 4.5, 'recent': []},
      },
    };

    final stats = await repo.getDashboard('r1');

    expect(api.lastGetPath, '/v1/api/restaurant-owner/dashboard');
    expect(api.lastGetQuery!['restaurantId'], 'r1',
        reason: 'backend silently falls back to the FIRST venue without it');
    expect(stats.orders.total, 5);
    expect(stats.reviews.averageRating, 4.5);
  });

  test('getOrders unwraps the NESTED envelope with pagination', () async {
    api.getResponse = {
      'success': true,
      'data': {
        'data': [
          {'_id': 'o1', 'orderNumber': 'ORD-1', 'orderStatus': 'pending'},
        ],
        'pagination': {'page': 2, 'limit': 20, 'total': 45, 'pages': 3},
      },
    };

    final page = await repo.getOrders('r1', page: 2, status: 'pending');

    expect(api.lastGetQuery!['restaurantId'], 'r1');
    expect(api.lastGetQuery!['page'], 2);
    expect(api.lastGetQuery!['status'], 'pending');
    expect(page.items.single.orderNumber, 'ORD-1');
    expect(page.page, 2);
    expect(page.pages, 3);
    expect(page.hasNext, isTrue);
  });

  test('getOrders tolerates the FLAT envelope shape', () async {
    api.getResponse = {
      'success': true,
      'data': [
        {'_id': 'o1', 'orderNumber': 'ORD-1', 'orderStatus': 'ready'},
      ],
    };

    final page = await repo.getOrders('r1');

    expect(page.items.single.orderStatus, 'ready');
    expect(page.total, 1);
  });

  test('getOrders throws a readable error on a missing payload', () async {
    api.getResponse = {'success': false};

    expect(repo.getOrders('r1'), throwsA('Empty response'));
  });

  test('updateOrderStatus PATCHes {status} and parses the returned order',
      () async {
    api.patchResponse = {
      'success': true,
      'data': {'_id': 'o1', 'orderNumber': 'ORD-1', 'orderStatus': 'confirmed'},
    };

    final updated =
        await repo.updateOrderStatus(id: 'o1', status: 'confirmed');

    expect(api.lastPatchPath, '/v1/api/restaurant-owner/orders/o1/status');
    expect(api.lastPatchBody, {'status': 'confirmed'});
    expect(updated.orderStatus, 'confirmed');
  });

  test('updateOrderStatus surfaces a 400 transition message verbatim',
      () async {
    api.patchError = DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 400,
        data: {
          'success': false,
          'message': 'Cannot change status from cancelled to confirmed',
        },
      ),
    );

    expect(repo.updateOrderStatus(id: 'o1', status: 'confirmed'),
        throwsA('Cannot change status from cancelled to confirmed'));
  });
}
