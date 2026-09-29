import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/widgets/primary/my_button.dart';
import 'package:tavo/core/widgets/primary/my_svg.dart';
import 'package:tavo/feature/onboarding/data/onboarding_data.dart';
import 'package:tavo/feature/onboarding/ui/cubit/onboarding_cubit.dart';
import 'package:tavo/feature/onboarding/ui/cubit/onboarding_state.dart';
import 'package:tavo/feature/onboarding/ui/widgets/onboarding_dot_indicator.dart';
import 'package:tavo/feature/onboarding/ui/widgets/onboarding_page.dart';
import 'package:tavo/feature/auth/ui/screens/login_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _contentAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _pages = OnboardingData.pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentAnimController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentAnimController, curve: Curves.easeOut),
    );
    _contentAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentAnimController.dispose();
    super.dispose();
  }

  void _onSkip(OnboardingCubit cubit) {
    final lastIndex = _pages.length - 1;
    cubit.onPageChanged(lastIndex);
    _pageController.animateToPage(
      lastIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// Staff entry: the restaurant button leaves onboarding for the staff
  /// login flow instead of re-navigating the already-visible last page.
  void _navigateToRestaurantLogin(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RestaurantLoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _onGetStarted() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
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
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocProvider(
      create: (_) => OnboardingCubit(),
      child: BlocConsumer<OnboardingCubit, OnboardingState>(
        listener: (context, state) {
          _pageController.animateToPage(
            state.currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
          _contentAnimController.reset();
          _contentAnimController.forward();
        },
        builder: (context, state) {
          final cubit = context.read<OnboardingCubit>();
          final currentData = _pages[state.currentPage];

          return Scaffold(
            body: Stack(
              children: [
                _buildPageView(cubit),
                _buildGradientOverlay(),
                _buildTopBar(state, cubit, textTheme),
                _buildBottomContent(state, cubit, currentData, textTheme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageView(OnboardingCubit cubit) {
    return Positioned.fill(
      child: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        onPageChanged: (index) {
          cubit.onPageChanged(index);
          _contentAnimController.reset();
          _contentAnimController.forward();
        },
        itemBuilder: (_, index) => OnboardingPage(data: _pages[index]),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: MediaQuery.of(context).size.height * 0.45,
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

  Widget _buildTopBar(
    OnboardingState state,
    OnboardingCubit cubit,
    TextTheme textTheme,
  ) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.h,
      left: 16.w,
      right: 16.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          state.currentPage > 0
              ? _buildCircleButton(
                  icon: Icons.arrow_back,
                  onTap: cubit.previousPage,
                )
              : SizedBox(width: 34.w),
          if (!state.isLastPage)
            _buildSkipButton(cubit, textTheme)
          else
            SizedBox(width: 60.w),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: ColorsManager.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18.sp, color: ColorsManager.white),
      ),
    );
  }

  Widget _buildSkipButton(OnboardingCubit cubit, TextTheme textTheme) {
    return GestureDetector(
      onTap: () => _onSkip(cubit),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: ColorsManager.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          'تخطي',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: ColorsManager.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent(
    OnboardingState state,
    OnboardingCubit cubit,
    dynamic currentData,
    TextTheme textTheme,
  ) {
    return Positioned(
      bottom: 32.h,
      left: 24.w,
      right: 24.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingDotIndicator(
            currentPage: state.currentPage,
            totalPages: _pages.length,
          ),
          SizedBox(height: 20.h),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Text(
                    currentData.title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: ColorsManager.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    currentData.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: ColorsManager.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 28.h),
          FadeTransition(
            opacity: _fadeAnimation,
            child: state.isLastPage
                ? Column(
                    children: [
                      MyButton(
                        onPressed: _onGetStarted,
                        label: 'مـتـابـعـة كـ مسـتـخـدم',
                        backgroundColor: ColorsManager.primaryColor,
                        textColor: ColorsManager.black,
                        radius: 80,
                        height: 48.h,
                        prefixIcon: const MySvg(
                          image: 'account',
                          applyColor: false,
                        ),
                        labelStyle: textTheme.titleMedium?.copyWith(
                          color: ColorsManager.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      MyButton(
                        onPressed: () => _navigateToRestaurantLogin(context),
                        label: 'مـتـابـعـة كـ مـطـعم',
                        backgroundColor:
                            ColorsManager.white.withValues(alpha: 0.08),
                        textColor: ColorsManager.white,
                        radius: 80,
                        height: 48.h,
                        prefixIcon: const MySvg(
                          image: 'restaurant',
                          applyColor: false,
                        ),
                        labelStyle: textTheme.titleMedium?.copyWith(
                          color: ColorsManager.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : MyButton(
                    onPressed: cubit.nextPage,
                    label: 'التالي',
                    backgroundColor: ColorsManager.primaryColor,
                    textColor: ColorsManager.white,
                    radius: 80,
                    height: 48.h,
                    labelStyle: textTheme.titleMedium?.copyWith(
                      color: ColorsManager.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
