import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Translations preloaded once per test file on the real event loop.
///
/// `rootBundle.loadString` only completes reliably outside `testWidgets`
/// (the fake-async zone cannot turn the real event loop that serves the
/// asset channel — only the first in-test load ever finished), so
/// [initTestEnv] reads the JSON here and the app shell serves it through
/// [_PreloadedAssetLoader] without touching the asset channel.
final Map<String, Map<String, dynamic>> preloadedTranslations = {};

/// One-time test environment setup: mock storage + EasyLocalization init
/// + preloaded translations. Call from `setUpAll`.
Future<void> initTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  if (preloadedTranslations.isEmpty) {
    for (final code in ['en', 'ar']) {
      final raw = await rootBundle.loadString('assets/translations/$code.json');
      preloadedTranslations[code] =
          json.decode(raw) as Map<String, dynamic>;
    }
  }
}

/// Serves translations from [preloadedTranslations]; never touches the
/// asset channel, so it completes with a plain microtask inside tests.
class PreloadedAssetLoader extends AssetLoader {
  const PreloadedAssetLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final code = locale.toStringWithSeparator(separator: '-');
    return preloadedTranslations[code] ??
        preloadedTranslations[locale.languageCode] ??
        const {};
  }
}

/// Pumps until [condition] is true (bounded). Needed because EasyLocalization
/// finishes loading its translations asynchronously and `pumpAndSettle` can
/// exit before the child subtree is built.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Wraps [child] in the same EasyLocalization + ScreenUtil + MaterialApp
/// shell the real app uses (mirrors `lib/main.dart`), forced to [locale] so
/// text finders are deterministic. Defaults to English; tests that care about
/// Arabic/RTL pass `locale: const Locale('ar')`.
Widget appShell(Widget child, {Locale locale = const Locale('en')}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/translations',
    assetLoader: const PreloadedAssetLoader(),
    startLocale: locale,
    fallbackLocale: const Locale('ar'),
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: child,
        );
      },
    ),
  );
}
