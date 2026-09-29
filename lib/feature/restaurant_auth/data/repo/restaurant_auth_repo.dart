import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_error_parser.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/auth/ui/data/models/auth_response.dart';
import 'package:tavo/feature/auth/ui/data/models/login_request.dart';
import 'package:tavo/feature/auth/ui/data/models/verify_otp_request.dart';
import 'package:tavo/feature/booking/data/model/booking_model.dart';

/// Staff-side API: restaurant OTP login plus the venue's reservations.
///
/// Mirrors [AuthRepo]'s error style (plain-string errors) so cubits and UI
/// treat both flows identically. Every authorized call relies on
/// `DioFactory`'s interceptor, which attaches `CacheHelper.getToken()`.
class RestaurantAuthRepo {
  final ApiService _apiService;

  RestaurantAuthRepo(this._apiService);

  /// Actions accepted by `PATCH /v1/api/reservation/:id/<action>`.
  static const List<String> reservationActions = [
    'confirm',
    'seat',
    'complete',
    'cancel',
    'no-show',
  ];

  Future<AuthResponse> restaurantLogin(LoginRequest request) async {
    try {
      final response = await _apiService.post(
        ApiConstants.restaurantLogin,
        data: request.toJson(),
      );
      await CacheHelper.setPhone(request.phone);
      await CacheHelper.setCountryCode(request.countryCode);
      return _parseAuth(response.data);
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<AuthResponse> verifyRestaurantOtp(VerifyOtpRequest request) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyRestaurantOtp,
        data: request.toJson(),
      );
      final auth = _parseAuth(response.data);
      if (auth.token != null && auth.token!.isNotEmpty) {
        await CacheHelper.setToken(auth.token!);
        await CacheHelper.setStaffMode(true);
      }
      if (auth.user != null) {
        await CacheHelper.setUser(jsonEncode(auth.user!.toJson()));
        if (auth.user!.id != null && auth.user!.id!.isNotEmpty) {
          await CacheHelper.setUserId(auth.user!.id!);
        }
        if (auth.user!.name != null && auth.user!.name!.isNotEmpty) {
          await CacheHelper.setUserName(auth.user!.name!);
        }
        if (auth.user!.phone != null) {
          await CacheHelper.setPhone(auth.user!.phone!);
        }
      }
      if (auth.restaurants.isNotEmpty) {
        await CacheHelper.setStaffRestaurants(
          jsonEncode(auth.restaurants.map((r) => r.toJson()).toList()),
        );
      }
      return auth;
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<BookingModel>> getRestaurantReservations(
    String restaurantId,
  ) async {
    try {
      final response = await _apiService.get(
        ApiConstants.restaurantReservations(restaurantId),
      );
      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] is Map<String, dynamic>) {
        final reservations =
            data['data']['reservations'] as List<dynamic>? ?? [];
        return reservations.map((e) => BookingModel.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<BookingModel> updateReservationStatus({
    required String id,
    required String action,
    String? reason,
  }) async {
    try {
      final response = await _apiService.patch(
        ApiConstants.reservationAction(id, action),
        data: action == 'cancel'
            ? {'reason': reason ?? 'Cancelled by restaurant'}
            : null,
      );
      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] != null) {
        return BookingModel.fromJson(data['data']);
      }
      throw (data is Map<String, dynamic> && data['message'] != null)
          ? data['message'].toString()
          : 'Failed to update reservation';
    } on DioException catch (e) {
      throw parseDioError(e);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> logout() async {
    await CacheHelper.clearUserData();
  }

  AuthResponse _parseAuth(dynamic data) {
    if (data == null) {
      return AuthResponse(success: false, message: 'Empty response');
    }
    if (data is String) {
      return AuthResponse(success: true, message: data);
    }
    if (data is Map<String, dynamic>) {
      return AuthResponse.fromJson(data);
    }
    return AuthResponse(success: false, message: 'Unknown response format');
  }
}
