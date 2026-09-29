import 'dart:async';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_state.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_home_screen.dart';

/// Staff OTP step. The cubit is handed over via `BlocProvider.value` from
/// [RestaurantLoginScreen], exactly like the customer [OtpScreen] flow.
class RestaurantOtpScreen extends StatefulWidget {
  final String phone;

  const RestaurantOtpScreen({super.key, required this.phone});

  @override
  State<RestaurantOtpScreen> createState() => _RestaurantOtpScreenState();
}

class _RestaurantOtpScreenState extends State<RestaurantOtpScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onResend() {
    if (_canResend) {
      context.read<RestaurantAuthCubit>().resendOtp();
    }
  }

  void _onVerify(String code) {
    if (code.length == 4) {
      context.read<RestaurantAuthCubit>().verifyOtp(code);
    }
  }

  void _navigateToHome(RestaurantAuthenticated state) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RestaurantHomeScreen(restaurants: state.restaurants),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RestaurantAuthCubit, RestaurantAuthState>(
      listener: (context, state) {
        if (state is RestaurantAuthenticated) {
          _navigateToHome(state);
        } else if (state is RestaurantOtpSent) {
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
        } else if (state is RestaurantAuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            _buildGradientOverlay(),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        AppAssets.onboarding3,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.65,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.9),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      bottom: 8.h,
      left: 8.w,
      right: 8.w,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: ColorsManager.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            verticalSpace(8),
            Text(
              'otp_title'.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: ColorsManager.black,
              ),
            ),
            verticalSpace(12),
            Text(
              'otp_subtitle'.tr(),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
                color: ColorsManager.dark500,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpace(32),
            _buildOtpInput(context),
            verticalSpace(16),
            _buildTimerRow(textTheme),
            verticalSpace(16),
            _buildVerifyButton(textTheme),
            verticalSpace(32),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpInput(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PinCodeTextField(
        appContext: context,
        length: 4,
        controller: _otpController,
        keyboardType: TextInputType.number,
        animationType: AnimationType.fade,
        animationDuration: const Duration(milliseconds: 200),
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(40.r),
          fieldHeight: 48.h,
          fieldWidth: 80.w,
          activeFillColor: ColorsManager.white,
          inactiveFillColor: ColorsManager.white,
          selectedFillColor: ColorsManager.white,
          activeColor: ColorsManager.primaryColor,
          inactiveColor: ColorsManager.lightGrey,
          selectedColor: ColorsManager.primaryColor,
        ),
        enableActiveFill: true,
        // The State owns _otpController and disposes it; letting the package
        // dispose it too throws "used after being disposed" on unmount.
        autoDisposeControllers: false,
        onCompleted: _onVerify,
        onChanged: (_) {},
      ),
    );
  }

  Widget _buildVerifyButton(TextTheme textTheme) {
    return BlocBuilder<RestaurantAuthCubit, RestaurantAuthState>(
      builder: (context, state) {
        final isLoading = state is RestaurantAuthLoading;
        return SizedBox(
          width: double.infinity,
          height: 48.h,
          child: MaterialButton(
            onPressed: isLoading ? null : () => _onVerify(_otpController.text),
            color: ColorsManager.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(80.r),
            ),
            elevation: 0,
            child: isLoading
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: const CircularProgressIndicator(
                      color: ColorsManager.black,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'verify'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: ColorsManager.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTimerRow(TextTheme textTheme) {
    return Row(
      children: [
        Text(
          _formattedTime,
          style: textTheme.bodyMedium?.copyWith(
            color: ColorsManager.darkGray300,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        BlocBuilder<RestaurantAuthCubit, RestaurantAuthState>(
          builder: (context, state) {
            final isLoading = state is RestaurantAuthLoading;
            return TextButton(
              onPressed: (_canResend && !isLoading) ? _onResend : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'resend_code'.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: _canResend
                      ? ColorsManager.primaryColor
                      : ColorsManager.darkGray300,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: _canResend
                      ? ColorsManager.primaryColor
                      : ColorsManager.darkGray300,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
