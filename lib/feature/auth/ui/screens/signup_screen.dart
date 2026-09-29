import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/helpers/utils/spacing.dart';
import 'package:tavo/core/widgets/primary/auth_text_form_field.dart';

import 'package:tavo/feature/auth/ui/logic/cubit/auth_cubit.dart';
import 'package:tavo/feature/auth/ui/logic/cubit/auth_state.dart';
import 'package:tavo/feature/auth/ui/screens/map_picker_screen.dart';
import 'package:tavo/feature/auth/ui/screens/otp_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthCubit>(),
      child: const _SignupScreenContent(),
    );
  }
}

class _SignupScreenContent extends StatefulWidget {
  const _SignupScreenContent();

  @override
  State<_SignupScreenContent> createState() => _SignupScreenContentState();
}

class _SignupScreenContentState extends State<_SignupScreenContent> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String _countryCode = '+966';
  LatLng? _selectedLocation;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onSignup() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().register(
            name: _nameController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            countryCode: _countryCode,
          );
    }
  }

  void _navigateToOtp(AuthCubit cubit) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BlocProvider.value(
          value: cubit,
          child: OtpScreen(phone: _phoneController.text),
        ),
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
    );
  }

  Future<void> _onPickLocation() async {
    final result = await Navigator.of(context).push<(LatLng, String)>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MapPickerScreen(initialLocation: _selectedLocation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result.$1;
        _locationController.text = result.$2.isNotEmpty
            ? result.$2
            : '${result.$1.latitude.toStringAsFixed(4)}, ${result.$1.longitude.toStringAsFixed(4)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          _navigateToOtp(context.read<AuthCubit>());
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
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
                'signup_title'.tr(),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ColorsManager.black,
                ),
              ),
              verticalSpace(12),
              Text(
                'signup_subtitle'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: ColorsManager.dark500,
                ),
                textAlign: TextAlign.center,
              ),
              verticalSpace(32),
              _buildNameField(),
              verticalSpace(12),
              _buildPhoneField(),
              verticalSpace(12),
              _buildEmailField(),
              verticalSpace(12),
              _buildLocationField(),
              verticalSpace(16),
              _buildSignupButton(textTheme),
              verticalSpace(16),
              _buildHaveAccountRow(textTheme),
              verticalSpace(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return AuthTextFormField(
      controller: _nameController,
      keyboardType: TextInputType.name,
      hint: 'name_hint'.tr(),
      borderRadius: 80,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'name_required'.tr();
        }
        return null;
      },
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

  Widget _buildEmailField() {
    return AuthTextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      hint: 'email_hint'.tr(),
      borderRadius: 80,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'email_required'.tr();
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'email_invalid'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildLocationField() {
    if (_selectedLocation != null) {
      return _buildLocationPreview();
    }
    return _buildLocationInput();
  }

  Widget _buildLocationInput() {
    return GestureDetector(
      onTap: _onPickLocation,
      child: Container(
        height: 48.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(80.r),
          border: Border.all(color: ColorsManager.lightGrey),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'location_hint'.tr(),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: ColorsManager.fontLightGrey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SvgPicture.asset(
              AppAssets.mapMarker,
              width: 30.w,
              height: 30.h,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPreview() {
    return GestureDetector(
      onTap: _onPickLocation,
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: ColorsManager.lightGrey),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _selectedLocation!,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rasad.tavo',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 32,
                        height: 32,
                        child: const Icon(
                          Icons.location_on,
                          color: ColorsManager.primaryColor,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8.h,
              right: 8.w,
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: ColorsManager.grey100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_location_outlined,
                  size: 18.sp,
                  color: ColorsManager.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupButton(TextTheme textTheme) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return SizedBox(
          width: double.infinity,
          height: 48.h,
          child: MaterialButton(
            onPressed: isLoading ? null : _onSignup,
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
                    'signup_button'.tr(),
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

  Widget _buildHaveAccountRow(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'have_account'.tr(),
          style: textTheme.bodyMedium?.copyWith(
            color: ColorsManager.black,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'sign_in'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              color: ColorsManager.primaryColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: ColorsManager.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
