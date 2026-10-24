// lib/feature/restaurant_panel/data/repo/restaurant_profile_repo.dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';

import '../model/restaurant_profile.dart';

class RestaurantProfileRepo {
  RestaurantProfileRepo(this._api);

  final ApiService _api;

  static const String _path = '${ApiConstants.panelBase}/profile';

  Map<String, dynamic> _data(dynamic body) {
    if (body is! Map) return const {};
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  Future<RestaurantProfile> getProfile(String restaurantId) async {
    try {
      final response = await _api.get(
        _path,
        queryParameters: {'restaurantId': restaurantId},
      );
      return RestaurantProfile.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  Future<RestaurantProfile> updateProfile(
    String restaurantId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _api.patch(
        _path,
        data: body,
        queryParameters: {'restaurantId': restaurantId},
      );
      return RestaurantProfile.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }

  /// [kind] is `logo` or `cover`.
  Future<RestaurantProfile> uploadImage({
    required String restaurantId,
    required String kind,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'image': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _api.post(
        '$_path/$kind',
        data: form,
        queryParameters: {'restaurantId': restaurantId},
      );
      return RestaurantProfile.fromJson(_data(response.data));
    } on DioException catch (error) {
      throw parseDioError(error);
    }
  }
}
