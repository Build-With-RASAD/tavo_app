import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/api_constants.dart';

/// Regression tests for production configuration.
///
/// Replaces the stock Flutter counter template test, which never applied to
/// this app (it referenced a counter UI that does not exist in TavoApp) and
/// therefore always failed.
void main() {
  group('Production configuration', () {
    test('API base URL points at the Tavo backend over HTTPS domain', () {
      expect(ApiConstants.baseUrl, 'https://tavo.abwabdigital.com');
    });

    test('base URL has no trailing slash (would break path joins)', () {
      expect(ApiConstants.baseUrl.endsWith('/'), isFalse);
    });

    test('absoluteUrl prefixes relative paths with the API base URL', () {
      expect(
        ApiConstants.absoluteUrl('/uploads/avatar.jpg'),
        'https://tavo.abwabdigital.com/uploads/avatar.jpg',
      );
    });

    test('absoluteUrl leaves already-absolute URLs untouched', () {
      expect(
        ApiConstants.absoluteUrl('https://cdn.example.com/x.png'),
        'https://cdn.example.com/x.png',
      );
    });

    test('native splash logo asset exists (flutter_native_splash input)', () {
      expect(File('assets/images/splash_logo.png').existsSync(), isTrue);
    });

    test('launcher icon source asset exists (flutter_launcher_icons input)',
        () {
      expect(File('assets/icons/logo_icon.png').existsSync(), isTrue);
    });
  });

  group('iOS production requirements (min iOS 15, current Apple rules)', () {
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    test('every IPHONEOS_DEPLOYMENT_TARGET in the Xcode project is >= 15.0',
        () {
      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toList();

      expect(targets, isNotEmpty,
          reason: 'no deployment targets found in project.pbxproj');
      for (final target in targets) {
        expect(
          double.parse(target),
          greaterThanOrEqualTo(15.0),
          reason:
              'IPHONEOS_DEPLOYMENT_TARGET $target is below 15.0 in project.pbxproj',
        );
      }
    });

    test('Podfile platform is >= iOS 15 (required by GoogleSignIn 8+)', () {
      final podfile = File('ios/Podfile').readAsStringSync();
      final match =
          RegExp(r"^platform :ios, '([\d.]+)'", multiLine: true).firstMatch(podfile);

      expect(match, isNotNull, reason: 'Podfile has no active platform line');
      expect(double.parse(match!.group(1)!), greaterThanOrEqualTo(15.0));
    });

    test('Podfile post_install raises stale pod targets to >= 15.0', () {
      final podfile = File('ios/Podfile').readAsStringSync();
      expect(podfile, contains('IPHONEOS_DEPLOYMENT_TARGET'),
          reason:
              'post_install must clamp pod deployment targets (several pods declare 9.0–14.0)');
    });

    test('Runner ships an app-level PrivacyInfo.xcprivacy', () {
      final manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
      expect(manifest.existsSync(), isTrue,
          reason:
              'Apple requires a privacy manifest for required-reason API usage');
      expect(pbxproj, contains('PrivacyInfo.xcprivacy'),
          reason: 'privacy manifest exists but is not wired into the Xcode project');
    });

    test('Info.plist declares export compliance (ITSAppUsesNonExemptEncryption)',
        () {
      final info = File('ios/Runner/Info.plist').readAsStringSync();
      expect(info, contains('ITSAppUsesNonExemptEncryption'),
          reason:
              'missing key forces the export-compliance question on every TestFlight/App Store build');
    });
  });
}
