// lib/feature/Profile/ui/screens/personal_info_screen.dart
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/localization/locale_keys.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/widgets/primary/auth_text_form_field.dart';
import 'package:tavo/feature/Profile/ui/logic/cubit/profile_cubit.dart';
import 'package:tavo/feature/Profile/ui/logic/cubit/profile_state.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProfileCubit>()..loadProfile(),
      child: const _PersonalInfoView(),
    );
  }
}

class _PersonalInfoView extends StatefulWidget {
  const _PersonalInfoView();

  @override
  State<_PersonalInfoView> createState() => _PersonalInfoViewState();
}

class _PersonalInfoViewState extends State<_PersonalInfoView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  String _originalName = '';
  String _originalPhone = '';
  bool _hasChanges = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_checkChanges);
    _phoneController.addListener(_checkChanges);
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkChanges);
    _phoneController.removeListener(_checkChanges);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initFields(ProfileState state) {
    if (!_initialized && state.user != null) {
      _originalName = state.user!.name;
      _originalPhone = state.user!.phone ?? '';
      _nameController.text = _originalName;
      _phoneController.text = _originalPhone;
      _initialized = true;
    }
  }

  void _checkChanges() {
    if (!mounted) return;
    final changed =
        _nameController.text.trim() != _originalName ||
        _phoneController.text.trim() != _originalPhone;
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<ProfileCubit>().updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.selectImageSource.tr(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: ColorsManager.black,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: LocaleKeys.camera.tr(),
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: LocaleKeys.gallery.tr(),
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60.r,
            height: 60.r,
            decoration: BoxDecoration(
              color: ColorsManager.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28.r, color: ColorsManager.primaryColor),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: ColorsManager.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        if (mounted) {
          context.read<ProfileCubit>().uploadAvatar(imageFile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.RTL;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (!mounted) return;
            _initFields(state);

            if (state.updateSuccess != null) {
              _originalName = _nameController.text.trim();
              _originalPhone = _phoneController.text.trim();
              if (mounted) setState(() => _hasChanges = false);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: ColorsManager.white,
                          size: 16.r,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        LocaleKeys.profileUpdatedSuccessfully.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF2E7D32),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              );
              if (mounted) context.read<ProfileCubit>().clearMessages();
            }

            if (state.error != null && !state.loading) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Container(
                        width: 28.r,
                        height: 28.r,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: ColorsManager.white,
                          size: 16.r,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFC62828),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              );
              if (mounted) context.read<ProfileCubit>().clearMessages();
            }
          },
          builder: (context, state) {
            if (state.loading && state.user == null) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ColorsManager.primaryColor,
                ),
              );
            }

            return Form(
              key: _formKey,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 36.r,
                            height: 36.r,
                            decoration: const BoxDecoration(
                              color: ColorsManager.grey100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                isRtl
                                    ? AppAssets.arrowRight
                                    : AppAssets.arrowLeft,
                                width: 16.r,
                                height: 16.r,
                                colorFilter: const ColorFilter.mode(
                                  ColorsManager.black,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.r),
                        Text(
                          LocaleKeys.myPersonalInfo.tr(),
                          style: TextStyle(
                            color: ColorsManager.black,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h),
                    Stack(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ColorsManager.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildAvatar(state),
                        ),
                        if (state.uploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 24.r,
                                  height: 24.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ColorsManager.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        PositionedDirectional(
                          bottom: 4.h,
                          start: 4.w,
                          child: GestureDetector(
                            onTap: state.uploadingAvatar
                                ? null
                                : _showImageSourceDialog,
                            child: Container(
                              width: 32.r,
                              height: 32.r,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F2F5F),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ColorsManager.white,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  AppAssets.edit,
                                  width: 14.r,
                                  height: 14.r,
                                  colorFilter: const ColorFilter.mode(
                                    ColorsManager.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h),
                    _buildLabel(context, LocaleKeys.name.tr()),
                    SizedBox(height: 8.h),
                    AuthTextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      hint: LocaleKeys.enterYourName.tr(),
                      borderRadius: 80,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? LocaleKeys.pleaseEnterName.tr()
                          : null,
                    ),
                    SizedBox(height: 20.h),
                    _buildLabel(context, LocaleKeys.phoneNumber.tr()),
                    SizedBox(height: 8.h),
                    AuthTextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      hint: LocaleKeys.phoneHint.tr(),
                      borderRadius: 80,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixIcon: Padding(
                        padding: EdgeInsets.all(10.w),
                        child: SvgPicture.asset(
                          AppAssets.countryFlags,
                          width: 22.w,
                          height: 22.h,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? LocaleKeys.pleaseEnterPhone.tr()
                          : null,
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 52.h,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _hasChanges && !state.updating
                            ? _onSave
                            : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: ColorsManager.primaryColor,
                          disabledBackgroundColor: ColorsManager.grey200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(80.r),
                          ),
                        ),
                        child: state.updating
                            ? SizedBox(
                                width: 22.r,
                                height: 22.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: ColorsManager.white,
                                ),
                              )
                            : Text(
                                LocaleKeys.saveChanges.tr(),
                                style: TextStyle(
                                  color: _hasChanges
                                      ? ColorsManager.white
                                      : ColorsManager.darkGray300,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(ProfileState state) {
    final imageUrl = state.user?.image;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final fullUrl = ApiConstants.absoluteUrl(imageUrl);
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          width: 88.r,
          height: 88.r,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 88.r,
            height: 88.r,
            color: ColorsManager.grey200,
            child: Icon(
              Icons.person,
              size: 40.r,
              color: ColorsManager.darkGray300,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 88.r,
            height: 88.r,
            color: ColorsManager.grey200,
            child: Icon(
              Icons.person,
              size: 40.r,
              color: ColorsManager.darkGray300,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 88.r,
      height: 88.r,
      decoration: const BoxDecoration(
        color: ColorsManager.grey200,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 40.r, color: ColorsManager.darkGray300),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: 8.w),
        child: Text(
          text,
          style: TextStyle(
            color: ColorsManager.black,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
