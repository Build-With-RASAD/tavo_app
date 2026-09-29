import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/constants/app_assets.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/auth/ui/screens/login_screen.dart';
import 'package:tavo/feature/home/ui/screens/main_nav_screen.dart';
import 'package:tavo/feature/onboarding/ui/screens/onboarding_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    final isLoggedIn = CacheHelper.isLoggedIn();
    final isOnboardingCompleted = CacheHelper.isOnboardingCompleted();

    Widget nextScreen;

    if (isLoggedIn && CacheHelper.isStaffMode()) {
      nextScreen = RestaurantHomeScreen(
        restaurants: _cachedStaffRestaurants(),
      );
    } else if (isLoggedIn) {
      nextScreen = const MainNavScreen();
    } else if (isOnboardingCompleted) {
      nextScreen = const LoginScreen();
    } else {
      nextScreen = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Staff venues cached at verify-OTP time. Empty (never null) when the
  /// cache is missing or corrupt — the home screen then shows `no_data`
  /// instead of crashing, and staff can log out / back in to refresh.
  List<StaffRestaurant> _cachedStaffRestaurants() {
    try {
      final raw = CacheHelper.getStaffRestaurants();
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(StaffRestaurant.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsManager.secondaryColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: SvgPicture.asset(
                  AppAssets.logo,
                  width: 150,
                  height: 168,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}