import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/core/widgets/primary/my_svg.dart';
import 'package:tavo/feature/auth/ui/data/models/auth_response.dart';
import 'package:tavo/feature/auth/ui/data/models/login_request.dart';
import 'package:tavo/feature/auth/ui/data/models/verify_otp_request.dart';
import 'package:tavo/feature/onboarding/ui/screens/onboarding_screen.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';
import 'dart:io';

import 'helpers/app_shell.dart';

/// Regression tests for two crashes on [OnboardingScreen]:
///
/// 1. Tapping the top "تخطي" skip button or the last-page
///    "متابعه ك مطعم" button threw
///    `ProviderNotFoundException: Provider<OnboardingCubit>`, because
///    `_onSkip()` called `context.read` on the State's own context, which
///    sits ABOVE the `BlocProvider` created inside `build()`.
/// 2. The last page rendered `MySvg(image: 'account (2)')`, but
///    `assets/icons/account (2).svg` does not exist ("Unable to load asset").
void main() {
  setUpAll(initTestEnv);

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(appShell(const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  }

  /// Advances with the "التالي" button (works via builder-scope cubit, so it
  /// isolates the asset bug from the provider bug) until the last page shows.
  Future<void> goToLastPage(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      expect(find.text('التالي'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('مـتـابـعـة كـ مسـتـخـدم'), findsOneWidget);
  }

  testWidgets('tapping the skip button jumps to the last page without '
      'a ProviderNotFoundException', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull,
        reason: '_onSkip must resolve OnboardingCubit instead of throwing '
            'ProviderNotFoundException');
    expect(find.text('مـتـابـعـة كـ مسـتـخـدم'), findsOneWidget);
  });

  testWidgets('tapping "متابعه ك مطعم" opens the restaurant login flow',
      (tester) async {
    final getIt = GetIt.instance;
    getIt.registerFactory<RestaurantAuthCubit>(
      () => RestaurantAuthCubit(_NoopRestaurantAuthRepo()),
    );
    addTearDown(getIt.reset);

    await pumpOnboarding(tester);
    await goToLastPage(tester);

    await tester.tap(find.text('مـتـابـعـة كـ مـطـعم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull,
        reason: 'navigating to the restaurant login must not throw');
    expect(find.byType(RestaurantLoginScreen), findsOneWidget);
  });

  testWidgets('every icon rendered on the last onboarding page exists on disk',
      (tester) async {
    await pumpOnboarding(tester);
    await goToLastPage(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'missing SVG asset ("Unable to load asset")');

    final svgs = tester.widgetList<MySvg>(find.byType(MySvg));
    expect(svgs, isNotEmpty);
    for (final svg in svgs) {
      final path = svg.isImage
          ? 'assets/images/${svg.image}.svg'
          : 'assets/icons/${svg.image}.svg';
      expect(File(path).existsSync(), isTrue,
          reason: 'MySvg(image: ${svg.image}) has no asset file at $path');
    }
  });
}

/// Never completes an API call; the navigation test only needs the screen
/// to build (its cubit is created from get_it on push).
class _NoopRestaurantAuthRepo extends RestaurantAuthRepo {
  _NoopRestaurantAuthRepo() : super(ApiService());

  @override
  Future<AuthResponse> restaurantLogin(LoginRequest request) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> verifyRestaurantOtp(VerifyOtpRequest request) =>
      throw UnimplementedError();
}
