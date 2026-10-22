// main.dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/navigation/app_navigator.dart';
import 'package:tavo/core/navigation/deep_link_navigator.dart';
import 'package:tavo/core/navigation/deep_link_service.dart';
import 'package:tavo/core/navigation/deep_link_target.dart';
import 'package:tavo/core/theme/app_theme.dart';
import 'package:tavo/feature/restaurant/ui/screens/restaurant_details_screen.dart';
import 'package:tavo/feature/splash/ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initServiceLocator();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      startLocale: const Locale('ar'),
      fallbackLocale: const Locale('ar'),
      child: const TavoApp(),
    ),
  );
}

/// The app root.
///
/// Owns the deep-link plumbing: a scanned QR encodes
/// `https://tavo.abwabdigital.com/menu/<slug>`, which the OS hands to the app
/// as an App Link / Universal Link (Android) or a Universal Link (iOS) when
/// the app is installed, and to Safari when it is not. A link that arrives
/// while the app is running is handled immediately; a link that *launched* the
/// app is resolved before the splash finishes, so it is buffered by
/// [DeepLinkNavigator] until the splash hands over the navigator.
class TavoApp extends StatefulWidget {
  const TavoApp({super.key});

  @override
  State<TavoApp> createState() => _TavoAppState();
}

class _TavoAppState extends State<TavoApp> {
  late final DeepLinkService _deepLinks;
  late final DeepLinkNavigator _deepLinkNavigator;
  StreamSubscription<DeepLinkTarget>? _subscription;

  @override
  void initState() {
    super.initState();

    _deepLinkNavigator = DeepLinkNavigator(
      onTarget: _openTarget,
      onUnresolved: _showRestaurantUnavailable,
    );

    _deepLinks = DeepLinkService(
      // A slug that cannot be resolved must NOT re-open the browser on the
      // same https URL: once the association files are live the OS would
      // route that URL straight back into the app, and the user would bounce
      // between the two forever. The app explains the situation instead.
      onUnresolvedLink: (_) => _deepLinkNavigator.reportUnresolved(),
    );

    // Subscribe BEFORE init() so the cold-start link is never missed.
    _subscription = _deepLinks.targets.listen(_onTarget);
    _deepLinks.init();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _deepLinks.dispose();
    super.dispose();
  }

  void _onTarget(DeepLinkTarget target) {
    switch (target) {
      case RestaurantDetailsTarget():
        _deepLinkNavigator.offer(target);
      default:
        // `DeepLinkTarget.none` and the slug variant never reach the UI: the
        // service resolves a slug to an id before emitting, and reports an
        // unresolvable link through `onUnresolvedLink` instead.
        break;
    }
  }

  void _openTarget(DeepLinkTarget target) {
    final restaurantId = target.restaurantId;
    if (restaurantId == null || restaurantId.isEmpty) return;

    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailsScreen(restaurantId: restaurantId),
      ),
    );
  }

  void _showRestaurantUnavailable() {
    final context = appNavigatorKey.currentContext ?? this.context;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text('dlink_restaurant_unavailable'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Tavo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          navigatorKey: appNavigatorKey,
          navigatorObservers: [_deepLinkNavigator],
          // These delegates handle RTL automatically
          localizationsDelegates: [
            ...context.localizationDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashScreen(),
        );
      },
    );
  }
}
