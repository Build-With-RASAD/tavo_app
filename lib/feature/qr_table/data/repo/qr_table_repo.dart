// lib/feature/qr_table/data/repo/qr_table_repo.dart
//
// Public, unauthenticated table API. Every call sets `skipAuth` so the shared
// Dio interceptor does not paste the signed-in customer's token over the guest
// bearer — the backend treats the two as different credentials.
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';

import '../model/table_session_models.dart';

class QrTableRepo {
  QrTableRepo(this._apiService);

  final ApiService _apiService;

  static const Map<String, dynamic> _publicExtra = {'skipAuth': true};

  Options _options({String? guestToken}) => Options(
        extra: _publicExtra,
        headers: guestToken == null
            ? null
            : {'Authorization': 'Bearer $guestToken'},
      );

  Map<String, dynamic> _data(dynamic body) {
    if (body is! Map) return const {};
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// `GET /v1/api/public/t/:qrToken`.
  Future<TableContext> resolve(String qrToken) async {
    try {
      final response = await _apiService.get(
        '/v1/api/public/t/$qrToken',
        options: _options(),
      );
      return TableContext.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  /// `POST /v1/api/public/t/:qrToken/session`.
  Future<JoinedTable> join(String qrToken, {String? name}) async {
    try {
      final response = await _apiService.post(
        '/v1/api/public/t/$qrToken/session',
        data: {
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
        options: _options(),
      );
      return JoinedTable.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  /// `GET /v1/api/public/session`.
  Future<TableSnapshot> state(String guestToken) async {
    try {
      final response = await _apiService.get(
        '/v1/api/public/session',
        options: _options(guestToken: guestToken),
      );
      return TableSnapshot.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  /// `POST /v1/api/public/session/orders`.
  Future<TableOrder> placeOrder(
    String guestToken,
    List<TableCartLine> lines, {
    String notes = '',
  }) async {
    try {
      final response = await _apiService.post(
        '/v1/api/public/session/orders',
        data: {
          'items': lines.map((line) => line.toJson()).toList(growable: false),
          if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
        options: _options(guestToken: guestToken),
      );
      final order = _data(response.data)['order'];
      return TableOrder.fromJson(
        order is Map ? Map<String, dynamic>.from(order) : const {},
      );
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  /// `POST /v1/api/public/session/rating`.
  Future<void> submitRating(String guestToken, RatingDraft draft) async {
    try {
      await _apiService.post(
        '/v1/api/public/session/rating',
        data: draft.toJson(),
        options: _options(guestToken: guestToken),
      );
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }
}

/// Remembers which guest token belongs to which printed table, so a guest who
/// closes the app does not rejoin as a second person (and a second cover).
abstract interface class TableGuestStore {
  Future<String?> read(String qrToken);
  Future<void> write(String qrToken, String guestToken);
  Future<void> clear();
}

class PrefsTableGuestStore implements TableGuestStore {
  static const String _key = 'qr_table_guest_token';

  @override
  Future<String?> read(String qrToken) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('$_key.qr') != qrToken) return null;
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String qrToken, String guestToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, guestToken);
    await prefs.setString('$_key.qr', qrToken);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('$_key.qr');
  }
}
