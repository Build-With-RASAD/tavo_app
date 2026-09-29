import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/core/widgets/primary/auth_text_form_field.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_state.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_otp_screen.dart';

/// Staff entry point: phone number → OTP (via `restaurant-login`).
/// Mirrors [LoginScreen] without the customer extras (social, signup).
class RestaurantLoginScreen extends StatelessWidget {
  const RestaurantLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<RestaurantAuthCubit>(),
      child: const _RestaurantLoginContent(),
    );
  }
}

class _RestaurantLoginContent extends StatefulWidget {
  const _RestaurantLoginContent();

  @override
  State<_RestaurantLoginContent> createState() =>
      _RestaurantLoginContentState();
}

class _RestaurantLoginContentState extends State<_RestaurantLoginContent> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String _countryCode = '+966';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<RestaurantAuthCubit>().restaurantLogin(
            phone: _phoneController.text,
            countryCode: _countryCode,
          );
    }
  }

  void _navigateToOtp(RestaurantAuthCubit cubit) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BlocProvider.value(
          value: cubit,
          child: RestaurantOtpScreen(phone: _phoneController.text),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RestaurantAuthCubit, RestaurantAuthState>(
      listener: (context, state) {
        if (state is RestaurantOtpSent) {
          _navigateToOtp(context.read<RestaurantAuthCubit>());
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              verticalSpace(8),
              Text(
                'restaurant_login_title'.tr(),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ColorsManager.black,
                ),
              ),
              verticalSpace(12),
              Text(
                'restaurant_login_subtitle'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: ColorsManager.dark500,
                ),
                textAlign: TextAlign.center,
              ),
              verticalSpace(32),
              _buildPhoneField(),
              verticalSpace(16),
              _buildLoginButton(textTheme),
              verticalSpace(35),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return AuthTextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      hint: 'phone_hint'.tr(),
      borderRadius: 80,
      textAlign: TextAlign.right,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      suffixIcon: Padding(
        padding: EdgeInsets.all(10.w),
        child: SvgPicture.asset(
          AppAssets.countryFlags,
          width: 24.w,
          height: 24.h,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'phone_required'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton(TextTheme textTheme) {
    return BlocBuilder<RestaurantAuthCubit, RestaurantAuthState>(
      builder: (context, state) {
        final isLoading = state is RestaurantAuthLoading;
        return SizedBox(
          width: double.infinity,
          height: 48.h,
          child: MaterialButton(
            onPressed: isLoading ? null : _onLogin,
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
                    'send_otp'.tr(),
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
}
