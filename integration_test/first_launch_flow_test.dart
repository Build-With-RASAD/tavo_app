// First-launch flow: fresh install -> splash -> onboarding (3 pages) ->
// login -> client-side validation -> OTP request -> wrong code rejected.
//
// Runs against the live backend http://46.202.134.87:4321. The only network
// writes are: a login OTP request for a sandbox phone number (backend replies
// "OTP sent successfully") and a wrong-OTP verification that always answers
// 400 "Invalid OTP" — no reservation or account state is ever created.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tavo/core/widgets/primary/my_button.dart';
import 'package:tavo/feature/auth/ui/screens/login_screen.dart';
import 'package:tavo/feature/auth/ui/screens/otp_screen.dart';
import 'package:tavo/feature/onboarding/data/onboarding_data.dart';
import 'package:tavo/feature/onboarding/ui/screens/onboarding_screen.dart';
import 'package:tavo/feature/splash/ui/screens/splash_screen.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install: splash -> onboarding -> login validation -> OTP -> '
    'wrong code rejected',
    (tester) async {
      await launchApp(tester, authenticated: false);

      // Splash shows first, then its 3s delay routes a fresh install to
      // onboarding (no token, no onboarding flag).
      await pumpUntil(
        tester,
        find.byType(SplashScreen),
        timeout: const Duration(seconds: 10),
        reason: 'app boots into SplashScreen',
      );
      await pumpUntil(
        tester,
        find.byType(OnboardingScreen),
        timeout: const Duration(seconds: 15),
        reason: 'splash routes a fresh install to onboarding',
      );

      // Page 1 (onboarding copy is hardcoded Arabic, locale-independent).
      expect(find.text(OnboardingData.pages[0].title), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await pumpUntil(
        tester,
        find.text(OnboardingData.pages[1].title),
        reason: 'onboarding advances to page 2',
      );
      await settle(tester);

      await tester.tap(find.text('التالي'));
      await pumpUntil(
        tester,
        find.text(OnboardingData.pages[2].title),
        reason: 'onboarding advances to the last page',
      );
      await settle(tester);

      // Last page shows two CTAs: continue as user (first) and continue as
      // restaurant (second).
      expect(
        find.byType(MyButton),
        findsNWidgets(2),
        reason: 'last onboarding page renders both CTAs',
      );
      await tester.tap(find.byType(MyButton).first);

      await pumpUntil(
        tester,
        find.byType(LoginScreen),
        timeout: const Duration(seconds: 10),
        reason: 'continue-as-user opens the login screen',
      );
      expect(find.text('Sign In'), findsOneWidget);

      // Empty phone -> client-side validation, no network call.
      await tester.tap(find.text('Send Verification Code'));
      await pumpUntil(
        tester,
        find.text('Please enter your phone number'),
        reason: 'empty phone is rejected by the form validator',
      );

      // Real OTP request for a sandbox number (backend replies
      // "OTP sent successfully" -> SendOtpSuccess -> OtpScreen).
      await tester.enterText(find.byType(TextFormField).first, '500000001');
      await settle(tester, 300);
      await tester.tap(find.text('Send Verification Code'));
      await pumpUntil(
        tester,
        find.byType(OtpScreen),
        reason: 'OTP screen opens after the backend accepts the phone number',
      );
      expect(find.text('Enter Verification Code'), findsOneWidget);

      // Wrong code: PinCodeTextField fires onCompleted ~300ms after the 4th
      // digit (auto-verify). Poll for the backend's 400 "Invalid OTP"
      // SnackBar; fall back to the visible Verify button if auto-verify
      // never ran.
      await tester.enterText(
        find
            .descendant(
              of: find.byType(OtpScreen),
              matching: find.byType(TextFormField),
            )
            .first,
        '0000',
      );
      var otpErrorShown = false;
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        if (find.text('Invalid OTP').evaluate().isNotEmpty) {
          otpErrorShown = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      }
      if (!otpErrorShown && find.text('Verify').evaluate().isNotEmpty) {
        await tester.tap(find.text('Verify'));
      }
      await pumpUntil(
        tester,
        find.text('Invalid OTP'),
        reason: 'wrong OTP is rejected with the backend 400 message',
      );

      expect(tester.takeException(), isNull);
    },
  );
}
