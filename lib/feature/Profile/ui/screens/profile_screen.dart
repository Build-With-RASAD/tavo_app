// lib/feature/Profile/ui/screens/profile_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/localization/locale_keys.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/theme/theme_extensions.dart';
import 'package:tavo/feature/Profile/ui/logic/cubit/profile_cubit.dart';
import 'package:tavo/feature/Profile/ui/logic/cubit/profile_state.dart';
import 'package:tavo/feature/auth/ui/screens/login_screen.dart';
import 'package:tavo/feature/booking/ui/screens/bookings_screen.dart';
import 'package:tavo/feature/notifications/ui/screens/notifications_screen.dart';
import 'package:tavo/feature/notifications/ui/logic/notifications_cubit.dart';
import 'package:tavo/feature/notifications/ui/logic/notifications_state.dart';
import 'package:tavo/feature/Profile/ui/screens/about_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/contact_us_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/help_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/language_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/personal_info_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/privacy_policy_screen.dart';
import 'package:tavo/feature/Profile/ui/screens/terms_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ProfileCubit>()..loadProfile()),
        BlocProvider(
          create: (_) =>
              getIt<NotificationsCubit>()
                ..loadNotifications(context.locale.languageCode),
        ),
      ],
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, state)),
              SliverToBoxAdapter(child: SizedBox(height: 16.h)),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: LocaleKeys.account.tr()),
                      SizedBox(height: 10.h),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            title: LocaleKeys.personalInfo.tr(),
                            icon: AppAssets.user,
                            onTap: () => _navigateTo(
                              context,
                              const PersonalInfoScreen(),
                            ),
                          ),
                          _MenuItem(
                            title: LocaleKeys.notifications.tr(),
                            icon: AppAssets.notification,
                            badge:
                                BlocBuilder<
                                  NotificationsCubit,
                                  NotificationsState
                                >(
                                  builder: (context, state) {
                                    if (state.unreadCount > 0) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 3.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ColorsManager.primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Text(
                                          state.unreadCount > 99
                                              ? '99+'
                                              : '${state.unreadCount}',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: ColorsManager.white,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                            onTap: () => _navigateTo(
                              context,
                              const NotificationsScreen(),
                            ),
                          ),
                          _MenuItem(
                            title: LocaleKeys.bookings.tr(),
                            icon: AppAssets.bookings,
                            onTap: () =>
                                _navigateTo(context, const BookingsScreen()),
                          ),
                          _MenuItem(
                            title: LocaleKeys.notifications.tr(),
                            icon: AppAssets.notification,
                            badge:
                                BlocBuilder<
                                  NotificationsCubit,
                                  NotificationsState
                                >(
                                  builder: (context, state) {
                                    if (state.unreadCount > 0) {
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 3.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ColorsManager.primaryColor,
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Text(
                                          state.unreadCount > 99
                                              ? '99+'
                                              : '${state.unreadCount}',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: ColorsManager.white,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                            onTap: () => _navigateTo(
                              context,
                              const NotificationsScreen(),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _SectionTitle(title: LocaleKeys.settings.tr()),
                      SizedBox(height: 10.h),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            title: LocaleKeys.language.tr(),
                            icon: AppAssets.language,
                            trailing: const _LanguageBadge(),
                            onTap: () =>
                                _navigateTo(context, const LanguageScreen()),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _SectionTitle(title: LocaleKeys.supportAndHelp.tr()),
                      SizedBox(height: 10.h),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            title: LocaleKeys.helpAndFaq.tr(),
                            icon: AppAssets.messageQuestion,
                            onTap: () =>
                                _navigateTo(context, const HelpScreen()),
                          ),
                          _MenuItem(
                            title: LocaleKeys.contactUs.tr(),
                            icon: AppAssets.headphone,
                            onTap: () =>
                                _navigateTo(context, const ContactUsScreen()),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _SectionTitle(title: LocaleKeys.legal.tr()),
                      SizedBox(height: 10.h),
                      _MenuCard(
                        items: [
                          _MenuItem(
                            title: LocaleKeys.privacyPolicy.tr(),
                            icon: AppAssets.shield,
                            onTap: () => _navigateTo(
                              context,
                              const PrivacyPolicyScreen(),
                            ),
                          ),
                          _MenuItem(
                            title: LocaleKeys.termsAndConditions.tr(),
                            icon: AppAssets.document,
                            onTap: () =>
                                _navigateTo(context, const TermsScreen()),
                          ),
                          _MenuItem(
                            title: LocaleKeys.aboutApp.tr(),
                            icon: AppAssets.info,
                            onTap: () =>
                                _navigateTo(context, const AboutScreen()),
                          ),
                        ],
                      ),
                      SizedBox(height: 30.h),
                      _buildLogoutButton(context),
                      SizedBox(height: 12.h),
                      _buildDeleteButton(context),
                      SizedBox(height: 30.h),
                      Center(
                        child: Text(
                          'Tavo v1.0.0',
                          style: TextStyles.font10DarkGray400Weight(
                            context,
                          ).copyWith(color: ColorsManager.darkGray300),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileState state) {
    return SizedBox(
      height: 220.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 150.h,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppAssets.headerHome),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28.r),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20.h,
                  right: -30.w,
                  child: Container(
                    width: 120.r,
                    height: 120.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorsManager.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -40.h,
                  left: -20.w,
                  child: Container(
                    width: 100.r,
                    height: 100.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorsManager.white.withOpacity(0.03),
                    ),
                  ),
                ),
                Positioned(
                  top: 10.h,
                  right: 16.w,
                  left: 16.w,
                  child: SafeArea(
                    child: Text(
                      LocaleKeys.profile.tr(),
                      style: TextStyle(
                        color: ColorsManager.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 100.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ColorsManager.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildAvatar(state, 76),
                ),
                SizedBox(height: 10.h),
                state.loading
                    ? _buildShimmerName()
                    : Column(
                        children: [
                          Text(
                            state.user?.name ?? '',
                            style: TextStyles.font14DarkGray400Weight(context)
                                .copyWith(
                                  color: ColorsManager.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16.sp,
                                ),
                          ),
                          SizedBox(height: 4.h),
                          if (state.user?.phone != null)
                            Text(
                              state.user!.phone!,
                              style: TextStyles.font12DarkGray400Weight(
                                context,
                              ).copyWith(color: ColorsManager.darkGray300),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ProfileState state, double size) {
    final imageUrl = state.user?.image;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final fullUrl = ApiConstants.absoluteUrl(imageUrl);
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          width: size.r,
          height: size.r,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size.r,
            height: size.r,
            color: ColorsManager.grey200,
            child: Icon(
              Icons.person,
              size: (size / 2).r,
              color: ColorsManager.darkGray300,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: size.r,
            height: size.r,
            color: ColorsManager.grey200,
            child: Icon(
              Icons.person,
              size: (size / 2).r,
              color: ColorsManager.darkGray300,
            ),
          ),
        ),
      );
    }
    return Container(
      width: size.r,
      height: size.r,
      decoration: const BoxDecoration(
        color: ColorsManager.grey200,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: (size / 2).r,
        color: ColorsManager.darkGray300,
      ),
    );
  }

  Widget _buildShimmerName() {
    return Column(
      children: [
        Container(
          width: 80.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: ColorsManager.grey200,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          width: 120.w,
          height: 10.h,
          decoration: BoxDecoration(
            color: ColorsManager.grey100,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return _ActionButton(
      title: LocaleKeys.logout.tr(),
      icon: AppAssets.logout,
      color: const Color(0xFFC62828),
      bgColor: const Color(0xFFFFF0F0),
      borderColor: const Color(0xFFFFDADA),
      onTap: () => _showConfirmSheet(
        context,
        title: LocaleKeys.logoutConfirmTitle.tr(),
        message: LocaleKeys.logoutConfirmMessage.tr(),
        confirmText: LocaleKeys.logout.tr(),
        onConfirm: () async {
          await CacheHelper.clearUserData();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return _ActionButton(
      title: LocaleKeys.deleteAccount.tr(),
      icon: AppAssets.trash,
      color: const Color(0xFFC62828),
      bgColor: ColorsManager.white,
      borderColor: const Color(0xFFFFDADA),
      onTap: () => _showConfirmSheet(
        context,
        title: LocaleKeys.deleteAccountConfirmTitle.tr(),
        message: LocaleKeys.deleteAccountConfirmMessage.tr(),
        confirmText: LocaleKeys.deleteAccount.tr(),
        onConfirm: () async {
          await CacheHelper.clearAll();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      if (context.mounted) {
        context.read<ProfileCubit>().loadProfile();
      }
    });
  }

  Future<void> _showConfirmSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required Future<void> Function() onConfirm,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: title,
        message: message,
        confirmText: confirmText,
      ),
    );

    if (result == true && context.mounted) {
      await onConfirm();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 4.w),
      child: Text(title, style: TextStyles.font16Black500Weight(context)),
    );
  }
}

class _MenuItem {
  final String title;
  final String icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? badge;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.badge,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? Radius.circular(18.r) : Radius.zero,
                    bottom: isLast ? Radius.circular(18.r) : Radius.zero,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 14.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34.r,
                          height: 34.r,
                          decoration: BoxDecoration(
                            color: ColorsManager.gray50,
                            borderRadius: BorderRadius.circular(40.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              item.icon,
                              width: 18.r,
                              height: 18.r,
                              colorFilter: const ColorFilter.mode(
                                ColorsManager.black,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyles.font12DarkGray400Weight(context)
                                .copyWith(
                                  color: ColorsManager.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                ),
                          ),
                        ),
                        if (item.badge != null) ...[
                          item.badge!,
                          SizedBox(width: 8.w),
                        ],
                        if (item.trailing != null) ...[
                          item.trailing!,
                          SizedBox(width: 8.w),
                        ],
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 15.r,
                          color: ColorsManager.darkGray300,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Divider(height: 1, color: context.borderColor),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge();

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.RTL;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: ColorsManager.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        isRtl ? 'العربية' : 'English',
        style: TextStyle(
          color: ColorsManager.primaryColor,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          height: 52.h,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                width: 18.r,
                height: 18.r,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;

  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: ColorsManager.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ColorsManager.grey200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              width: 56.r,
              height: 56.r,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 28.r,
                color: const Color(0xFFC62828),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                color: ColorsManager.black,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: TextStyles.font12DarkGray400Weight(
                context,
              ).copyWith(fontWeight: FontWeight.w500, height: 1.6),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(80.r),
                        ),
                        side: BorderSide(color: context.borderColor),
                      ),
                      child: Text(
                        LocaleKeys.cancel.tr(),
                        style: TextStyle(
                          color: ColorsManager.black,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFC62828),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(80.r),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          color: ColorsManager.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
