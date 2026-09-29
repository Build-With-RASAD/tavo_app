import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/auth/ui/data/models/login_request.dart';
import 'package:tavo/feature/auth/ui/data/models/verify_otp_request.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'restaurant_auth_state.dart';

/// Staff-side counterpart of [AuthCubit]: phone → OTP → authenticated with
/// the venue list. Keeps the entered phone in memory so verify/resend reuse it.
class RestaurantAuthCubit extends Cubit<RestaurantAuthState> {
  final RestaurantAuthRepo _repo;

  RestaurantAuthCubit(this._repo) : super(RestaurantAuthInitial());

  String _phone = '';
  String _countryCode = '+966';

  String get phone => _phone;
  String get countryCode => _countryCode;

  Future<void> restaurantLogin({
    required String phone,
    required String countryCode,
  }) async {
    emit(RestaurantAuthLoading());
    try {
      final response = await _repo.restaurantLogin(
        LoginRequest(countryCode: countryCode, phone: phone),
      );
      _phone = phone;
      _countryCode = countryCode;
      emit(
        RestaurantOtpSent(
          phone: phone,
          countryCode: countryCode,
          restaurants: response.restaurants,
        ),
      );
    } catch (e) {
      emit(RestaurantAuthError(_message(e)));
    }
  }

  Future<void> verifyOtp(String otp) async {
    emit(RestaurantAuthLoading());
    try {
      final response = await _repo.verifyRestaurantOtp(
        VerifyOtpRequest(
          countryCode: _countryCode,
          phone: _phone,
          otp: otp,
        ),
      );
      emit(
        RestaurantAuthenticated(
          restaurants: response.restaurants,
          isOwner: response.isRestaurantOwner,
        ),
      );
    } catch (e) {
      emit(RestaurantAuthError(_message(e)));
    }
  }

  Future<void> resendOtp() async {
    emit(RestaurantAuthLoading());
    try {
      final response = await _repo.restaurantLogin(
        LoginRequest(countryCode: _countryCode, phone: _phone),
      );
      emit(
        RestaurantOtpSent(
          phone: _phone,
          countryCode: _countryCode,
          restaurants: response.restaurants,
        ),
      );
    } catch (e) {
      emit(RestaurantAuthError(_message(e)));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(RestaurantAuthInitial());
  }

  String _message(dynamic error) =>
      error is String ? error : error.toString();
}
