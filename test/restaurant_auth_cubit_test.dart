import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/auth/ui/data/models/auth_response.dart';
import 'package:tavo/feature/auth/ui/data/models/login_request.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/auth/ui/data/models/verify_otp_request.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_state.dart';

/// Hand-rolled fake in the style of the existing `FakeBookingsCubit`:
/// subclasses the real repo so no mock package is needed.
class FakeRestaurantAuthRepo extends RestaurantAuthRepo {
  FakeRestaurantAuthRepo() : super(ApiService());

  AuthResponse? loginResult;
  Object? loginError;
  AuthResponse? verifyResult;
  Object? verifyError;
  int loginCalls = 0;
  int verifyCalls = 0;

  @override
  Future<AuthResponse> restaurantLogin(LoginRequest request) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AuthResponse> verifyRestaurantOtp(VerifyOtpRequest request) async {
    verifyCalls++;
    if (verifyError != null) throw verifyError!;
    return verifyResult!;
  }
}

AuthResponse _loginOk(List<StaffRestaurant> restaurants) => AuthResponse(
      success: true,
      message: 'OTP sent successfully',
      hasRestaurantAccess: true,
      restaurants: restaurants,
    );

StaffRestaurant _burgerLab() => StaffRestaurant(
      restaurantId: 'r1',
      name: 'برغر لاب',
      nameEn: 'Burger Lab',
      nameAr: 'برغر لاب',
      role: 'owner',
      permissions: const ['full_access'],
      status: 'active',
    );

void main() {
  late FakeRestaurantAuthRepo repo;
  late RestaurantAuthCubit cubit;

  setUp(() {
    repo = FakeRestaurantAuthRepo();
    cubit = RestaurantAuthCubit(repo);
  });

  tearDown(() => cubit.close());

  test('restaurantLogin emits OtpSent with the staff restaurants', () async {
    repo.loginResult = _loginOk([_burgerLab()]);

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantAuthLoading>(),
        predicate<RestaurantOtpSent>(
          (s) =>
              s.phone == '557164151' &&
              s.countryCode == '+966' &&
              s.restaurants.map((r) => r.nameEn).toList().join() ==
                  'Burger Lab',
        ),
      ]),
    );
    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');
    await expectation;

    expect(repo.loginCalls, 1);
  });

  test('restaurantLogin surfaces a 403 (no assignment) as an error', () async {
    repo.loginError = 'You are not assigned to any restaurant';

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantAuthLoading>(),
        predicate<RestaurantAuthError>(
          (s) => s.message.contains('not assigned'),
        ),
      ]),
    );
    await cubit.restaurantLogin(phone: '500000000', countryCode: '+966');
    await expectation;
  });

  test('verifyOtp emits Authenticated with restaurants + owner flag', () async {
    repo.loginResult = _loginOk([_burgerLab()]);
    repo.verifyResult = AuthResponse(
      success: true,
      token: 'tok',
      restaurants: [_burgerLab()],
      isRestaurantOwner: true,
    );

    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantAuthLoading>(),
        predicate<RestaurantAuthenticated>(
          (s) =>
              s.isOwner &&
              s.restaurants.single.nameEn == 'Burger Lab',
        ),
      ]),
    );
    await cubit.verifyOtp('1111');
    await expectation;

    expect(repo.verifyCalls, 1);
  });

  test('verifyOtp with a wrong OTP emits an error, not Authenticated',
      () async {
    repo.loginResult = _loginOk([_burgerLab()]);
    repo.verifyError = 'Invalid OTP';

    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantAuthLoading>(),
        predicate<RestaurantAuthError>(
          (s) => s.message.contains('Invalid OTP'),
        ),
      ]),
    );
    await cubit.verifyOtp('0000');
    await expectation;
  });

  test('resendOtp re-sends to the stored phone', () async {
    repo.loginResult = _loginOk([_burgerLab()]);
    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');

    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        isA<RestaurantAuthLoading>(),
        predicate<RestaurantOtpSent>((s) => s.phone == '557164151'),
      ]),
    );
    await cubit.resendOtp();
    await expectation;

    expect(repo.loginCalls, 2);
  });

  test('logout returns to the initial state', () async {
    repo.loginResult = _loginOk([_burgerLab()]);
    await cubit.restaurantLogin(phone: '557164151', countryCode: '+966');

    final expectation = expectLater(
      cubit.stream,
      emitsThrough(isA<RestaurantAuthInitial>()),
    );
    await cubit.logout();
    await expectation;
  });
}
